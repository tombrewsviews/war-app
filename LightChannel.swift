import AVFoundation
import CoreMedia
import Synchronization

/// A single detected transition of the light channel (torch/flash as seen through the camera).
struct LightEdge: Sendable {
    let isOn: Bool
    let timestamp: TimeInterval
}

/// Adaptive-threshold edge detection state, shared between the (MainActor) session-management
/// code and the background video-output callback via a `Mutex`.
private struct DetectionState {
    var calibrationSamples: [Double] = []
    var baseline: Double = 0
    var isBaselineReady = false
    var lastState = false
}

/// Owns the rear camera + torch and turns the raw video feed into a stream of on/off transitions.
final class LightChannel: NSObject {
    enum ChannelError: Error {
        case cameraUnavailable
    }

    private let session = AVCaptureSession()
    private let videoOutputQueue = DispatchQueue(label: "LightChannel.videoOutput")

    private var device: AVCaptureDevice?

    // `captureOutput` runs on `videoOutputQueue`; `Mutex` is itself `Sendable` so this needs no
    // isolation escape, but the continuation does since `AsyncStream.Continuation` is stored, not just used.
    private let detectionState = Mutex(DetectionState())
    nonisolated(unsafe) private var edgeContinuation: AsyncStream<LightEdge>.Continuation?

    private let calibrationSampleCount = 8
    private let onMultiplier = 1.35
    private let onMargin = 5.0
    private let offMultiplier = 1.16
    private let offMargin = 2.0
    private let baselineSmoothing = 0.08

    private(set) lazy var previewLayer = AVCaptureVideoPreviewLayer(session: session)

    static func requestAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    static var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    /// Configures and starts the capture session, returning a stream of light-edge events.
    func start() async throws -> AsyncStream<LightEdge> {
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw ChannelError.cameraUnavailable
        }
        self.device = device

        session.beginConfiguration()
        session.sessionPreset = .low

        if session.inputs.isEmpty {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        if session.outputs.isEmpty {
            let output = AVCaptureVideoDataOutput()
            output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: videoOutputQueue)
            if session.canAddOutput(output) {
                session.addOutput(output)
            }
        }

        session.commitConfiguration()

        try? device.lockForConfiguration()
        // Keep sampling deterministic and as fast as the active camera format
        // allows (up to 60 fps). Auto frame-rate reduction would otherwise make
        // pulse durations vary with ambient light.
        if let range = device.activeFormat.videoSupportedFrameRateRanges.max(by: { $0.maxFrameRate < $1.maxFrameRate }) {
            let targetRate = min(range.maxFrameRate, 60)
            if targetRate >= range.minFrameRate {
                let duration = CMTime(value: 1, timescale: CMTimeScale(targetRate.rounded()))
                device.activeVideoMinFrameDuration = duration
                device.activeVideoMaxFrameDuration = duration
            }
        }
        if device.isFocusModeSupported(.continuousAutoFocus) {
            device.focusMode = .continuousAutoFocus
        }
        if device.isExposureModeSupported(.autoExpose) {
            device.exposureMode = .autoExpose
        }
        device.unlockForConfiguration()

        let stream = AsyncStream<LightEdge> { continuation in
            self.edgeContinuation = continuation
        }

        let session = self.session
        await Task.detached { [session] in
            session.startRunning()
        }.value

        // Let auto-exposure converge on ambient conditions briefly, then actually lock it in
        // place. Left on continuous auto-exposure (as it was before — this lock call never ran),
        // the camera keeps compensating for every incoming light pulse it sees, flattening out
        // exactly the brightness swings edge detection depends on. Calibration is deliberately
        // reset only after locking, so the baseline reflects the final locked exposure rather
        // than a still-adjusting one.
        try? await Task.sleep(nanoseconds: 400_000_000)
        if device.isExposureModeSupported(.locked) {
            try? device.lockForConfiguration()
            device.exposureMode = .locked
            device.unlockForConfiguration()
        }
        detectionState.withLock { $0 = DetectionState() }

        return stream
    }

    func stop() {
        setTorch(false)
        let session = self.session
        Task.detached { [session] in
            session.stopRunning()
        }
        edgeContinuation?.finish()
        edgeContinuation = nil
    }

    func setTorch(_ on: Bool) {
        guard let device, device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            // Best effort only — a failed torch toggle shouldn't crash a signaling attempt.
        }
    }
}

extension LightChannel: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let luma = Self.averageLuma(of: pixelBuffer)
        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        handle(sample: luma, at: timestamp)
    }

    nonisolated private func handle(sample luma: Double, at timestamp: TimeInterval) {
        let edge: LightEdge? = detectionState.withLock { state in
            if !state.isBaselineReady {
                state.calibrationSamples.append(luma)
                if state.calibrationSamples.count >= calibrationSampleCount {
                    state.baseline = state.calibrationSamples.reduce(0, +) / Double(state.calibrationSamples.count)
                    state.isBaselineReady = true
                }
                return nil
            }

            // Hysteresis prevents frame-to-frame noise around the threshold from producing
            // false on/off edges. Use a stricter threshold to turn on than to stay on.
            let isOn: Bool
            if state.lastState {
                isOn = luma > state.baseline * offMultiplier + offMargin
            } else {
                isOn = luma > state.baseline * onMultiplier + onMargin
            }

            // Only drift the baseline while dark, so a bright pulse doesn't drag it upward mid-flash.
            if !isOn {
                state.baseline = state.baseline * (1 - baselineSmoothing) + luma * baselineSmoothing
            }

            guard isOn != state.lastState else { return nil }
            state.lastState = isOn
            return LightEdge(isOn: isOn, timestamp: timestamp)
        }

        if let edge {
            edgeContinuation?.yield(edge)
        }
    }

    /// Averages luma over the central third of the frame, since that's where the other device's light should be aimed.
    nonisolated private static func averageLuma(of pixelBuffer: CVPixelBuffer) -> Double {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        guard let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return 0 }
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)

        let regionWidth = max(width / 3, 1)
        let regionHeight = max(height / 3, 1)
        let startX = width / 2 - regionWidth / 2
        let startY = height / 2 - regionHeight / 2

        let buffer = base.assumingMemoryBound(to: UInt8.self)
        var total = 0
        var count = 0

        var y = startY
        while y < startY + regionHeight {
            let rowStart = y * bytesPerRow
            var x = startX
            while x < startX + regionWidth {
                total += Int(buffer[rowStart + x])
                count += 1
                x += 4
            }
            y += 4
        }

        return count > 0 ? Double(total) / Double(count) : 0
    }
}
