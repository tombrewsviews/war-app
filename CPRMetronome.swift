import AVFoundation

/// Drives an audible + visual CPR pace: a click at the recommended compression tempo (110/min,
/// inside the 100–120 guideline range), and a distinct cue for the "2 breaths" pause after every
/// 30 compressions — the auto-counted 30:2 cycle most first-aid apps leave to the user to track
/// themselves. Tones are synthesized at runtime (no bundled audio files needed).
@MainActor
@Observable
final class CPRMetronome {
    enum Phase: Equatable {
        case stopped
        case compressions(count: Int)
        case breaths
    }

    private(set) var phase: Phase = .stopped
    private(set) var isRunning = false

    private let compressionsPerCycle = 30
    private let breathPauseSeconds: TimeInterval = 4.0
    private let bpm: Double = 110
    private var compressionInterval: TimeInterval { 60.0 / bpm }

    // Audio setup touches AVAudioSession, which can block for a while doing IPC with the audio
    // daemon — that's flagged as a "Hang Risk" if done on the main thread. These are opted out of
    // MainActor isolation so `prepareEngineIfNeeded()` can run on a background thread instead;
    // they're only ever touched sequentially (setup once, then playback), never concurrently.
    @ObservationIgnored private let engine = AVAudioEngine()
    @ObservationIgnored private let player = AVAudioPlayerNode()
    @ObservationIgnored nonisolated(unsafe) private var compressionBuffer: AVAudioPCMBuffer?
    @ObservationIgnored nonisolated(unsafe) private var breathBuffer: AVAudioPCMBuffer?
    @ObservationIgnored nonisolated(unsafe) private var isEngineReady = false
    @ObservationIgnored private var loopTask: Task<Void, Never>?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        loopTask = Task {
            await prepareEngineIfNeeded()
            await runLoop()
        }
    }

    func stop() {
        isRunning = false
        loopTask?.cancel()
        loopTask = nil
        phase = .stopped
        player.stop()
    }

    private func runLoop() async {
        while !Task.isCancelled {
            for count in 1...compressionsPerCycle {
                guard !Task.isCancelled else { return }
                phase = .compressions(count: count)
                playCompressionTick()
                try? await Task.sleep(nanoseconds: UInt64(compressionInterval * 1_000_000_000))
            }
            guard !Task.isCancelled else { return }
            phase = .breaths
            playBreathCue()
            try? await Task.sleep(nanoseconds: UInt64(breathPauseSeconds * 1_000_000_000))
        }
    }

    /// `nonisolated` alone doesn't move work off the main thread — a `Task` created from a MainActor
    /// context still runs on it unless something explicitly detaches. `Task.detached` is what
    /// actually keeps the potentially slow `AVAudioSession` activation off the UI thread.
    nonisolated private func prepareEngineIfNeeded() async {
        guard !isEngineReady else { return }

        let engine = self.engine
        let player = self.player

        let buffers = await Task.detached { () -> (AVAudioPCMBuffer?, AVAudioPCMBuffer?) in
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try? AVAudioSession.sharedInstance().setActive(true)

            engine.attach(player)
            let format = engine.outputNode.inputFormat(forBus: 0)
            try? engine.connectNode(player, to: engine.mainMixerNode, format: format)
            try? engine.start()

            return (
                Self.makeToneBuffer(frequency: 900, duration: 0.06, format: format),
                Self.makeToneBuffer(frequency: 500, duration: 0.35, format: format)
            )
        }.value

        compressionBuffer = buffers.0
        breathBuffer = buffers.1
        isEngineReady = true
    }

    private func playCompressionTick() {
        guard let buffer = compressionBuffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { try? player.playAudio() }
    }

    private func playBreathCue() {
        guard let buffer = breathBuffer else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.scheduleBuffer(buffer, at: nil)
        if !player.isPlaying { try? player.playAudio() }
    }

    nonisolated private static func makeToneBuffer(frequency: Double, duration: Double, format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
              let channelData = buffer.floatChannelData
        else { return nil }

        buffer.frameLength = frameCount
        let channelCount = Int(format.channelCount)
        let total = Int(frameCount)
        let fadeSamples = max(1, min(200, total / 4))

        for frame in 0..<total {
            let envelope: Float
            if frame < fadeSamples {
                envelope = Float(frame) / Float(fadeSamples)
            } else if frame > total - fadeSamples {
                envelope = Float(total - frame) / Float(fadeSamples)
            } else {
                envelope = 1.0
            }

            let sample = Float(sin(2.0 * Double.pi * frequency * Double(frame) / sampleRate)) * envelope * 0.4
            for channel in 0..<channelCount {
                channelData[channel][frame] = sample
            }
        }

        return buffer
    }
}
