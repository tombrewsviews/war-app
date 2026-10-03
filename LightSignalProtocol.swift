import SwiftUI
import AVFoundation

// MARK: - Incremental decoder

/// Turns a stream of (isOn, duration) pulses back into text, mirroring `SignalEncoder`'s timing rules.
struct SignalDecoder {
    enum FirflyFormat {
        case control
        case packet
    }

    private let mode: SignalMode
    private let unit: TimeInterval
    private let firflyFormat: FirflyFormat

    private var morseSymbols = ""
    private var fireflyBits: [UInt8] = []
    private var fireflyBytes: [UInt8] = []
    private var isFirflySynchronized: Bool

    private static let reverseMorseTable: [String: Character] = {
        var reversed: [String: Character] = [:]
        for (character, code) in SignalEncoder.morseTable {
            reversed[code] = character
        }
        return reversed
    }()

    init(mode: SignalMode, unit: TimeInterval, firflyFormat: FirflyFormat = .control) {
        self.mode = mode
        self.unit = unit
        self.firflyFormat = firflyFormat
        self.isFirflySynchronized = false
    }

    /// Feeds one pulse into the decoder. Returns any text newly decoded as a result.
    mutating func consume(isOn: Bool, duration: TimeInterval) -> String? {
        switch mode {
        case .morse, .continuousMorse: return consumeMorse(isOn: isOn, duration: duration)
        case .firefly: return consumeFirefly(isOn: isOn, duration: duration)
        }
    }

    /// Flushes any letter still buffered when the transmission ends without a trailing gap.
    mutating func flush() -> String? {
        switch mode {
        case .morse, .continuousMorse:
            guard !morseSymbols.isEmpty else { return nil }
            defer { morseSymbols = "" }
            return Self.reverseMorseTable[morseSymbols].map(String.init)
        case .firefly:
            guard firflyFormat == .packet else { return nil }
            return FirflyFrame.decode(fireflyBytes)
        }
    }

    private mutating func consumeMorse(isOn: Bool, duration: TimeInterval) -> String? {
        if isOn {
            morseSymbols += duration < unit * 2 ? "." : "-"
            return nil
        }

        guard duration >= unit * 2 else { return nil } // intra-letter gap: more symbols coming

        defer { morseSymbols = "" }
        let letter = Self.reverseMorseTable[morseSymbols].map(String.init) ?? ""
        return duration >= unit * 5 ? letter + " " : letter
    }

    private mutating func consumeFirefly(isOn: Bool, duration: TimeInterval) -> String? {
        guard isOn else { return nil }

        if duration >= unit * 5 {
            // Every control frame and Firfly payload begins with this pulse. It is
            // outside the 1-unit/3-unit data alphabet, so the decoder can recover
            // byte alignment after a missed or reflected edge. A later marker in a
            // payload leaves already captured bytes intact: that payload contains a
            // second frame and `FirflyFrame.decode` will accept either valid copy.
            if !isFirflySynchronized {
                fireflyBits = []
                fireflyBytes = []
            }
            isFirflySynchronized = true
            return nil
        }
        guard isFirflySynchronized else { return nil }

        let bit: UInt8 = duration < unit * 2 ? 0 : 1
        fireflyBits.append(bit)
        let bitCount = firflyFormat == .control ? 7 : 8
        guard fireflyBits.count == bitCount else { return nil }

        let byte = fireflyBits.reduce(UInt8(0)) { ($0 << 1) | $1 }
        fireflyBits = []
        switch firflyFormat {
        case .control:
            return String(Character(Unicode.Scalar(byte)))
        case .packet:
            fireflyBytes.append(byte)
            return nil
        }
    }
}

// MARK: - Handshake mode tag

/// A single control-frame character identifying which encoding an RTS announces, so the receiver
/// knows exactly which decoder to use for the payload that follows — no guessing.
extension SignalMode {
    var controlChar: Character {
        switch self {
        case .morse: return "M"
        case .firefly: return "F"
        case .continuousMorse: return "C"
        }
    }

    init?(controlChar: Character) {
        switch controlChar {
        case "M": self = .morse
        case "F": self = .firefly
        default: return nil
        }
    }
}

// MARK: - Received message model

struct ReceivedMessage: Identifiable {
    let id = UUID()
    let text: String
    let mode: SignalMode
    let date: Date
}

// MARK: - Edge source (single consumer of the camera's edge stream)

/// Buffers edges from the camera's `AsyncStream` behind a single, always-running drain loop, so
/// that repeated timed-out "wait for the next edge" calls never need to start a second concurrent
/// call against the underlying stream's iterator.
///
/// The previous implementation raced a fresh `iterator.next()` call against a timeout with
/// `withTaskGroup`/`cancelAll()` on every wait. When the timeout won — which happens constantly
/// while idly listening for an incoming signal — the losing `next()` call didn't actually stop:
/// `AsyncStream.AsyncIterator.next()` doesn't return early on cancellation, so it kept running,
/// orphaned, holding its own copy of the iterator. The next listen attempt then started a *second*
/// call against the iterator still stored on the actor, so two calls ended up contending for the
/// same underlying stream — undefined behavior for `AsyncSequence`, and in practice it meant edges
/// were silently dropped or misrouted, so receiving never worked. Having exactly one loop ever call
/// into the stream avoids this entirely.
private actor EdgeSource {
    private var buffer: [LightEdge] = []

    init(_ stream: AsyncStream<LightEdge>) {
        Task { [weak self] in
            for await edge in stream {
                await self?.append(edge)
            }
        }
    }

    private func append(_ edge: LightEdge) {
        buffer.append(edge)
    }

    /// Pops the next buffered edge, waiting up to `timeout` if none has arrived yet.
    func next(timeout: TimeInterval) async -> LightEdge? {
        let deadline = CACurrentMediaTime() + timeout
        while buffer.isEmpty {
            guard CACurrentMediaTime() < deadline else { return nil }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        return buffer.removeFirst()
    }

    /// Discards any buffered edges. Our own torch flashing (sending RTS/CTS/ACK/payload) can bleed
    /// into our own camera's exposure — reflections, close proximity, etc. — and get misdetected as
    /// incoming edges. Calling this right after we finish transmitting, before we start listening
    /// for the other side's response, throws away that self-interference instead of letting it
    /// misalign the very next decode (which is fatal for Firfly's fixed-position byte framing, even
    /// though Morse's timing-based decoding happens to tolerate it).
    func reset() {
        buffer.removeAll()
    }
}

// MARK: - Session coordinator

@MainActor
@Observable
final class LightSessionCoordinator {
    enum OperatingMode { case standard, continuousMorse }
    enum Phase: Equatable {
        case idle
        case checkingChannel
        case channelBusy
        case sendingRTS
        case awaitingCTS
        case receivingHandshake
        case transmittingPayload
        case receivingPayload
        case sent(String)
        case receivedMessage(String)
        case failed(String)

        var label: String {
            switch self {
            case .idle: return "Oczekiwanie"
            case .checkingChannel: return "Oczekiwanie"
            case .channelBusy: return "Kanał zajęty"
            case .sendingRTS, .awaitingCTS: return "Łączenie"
            case .receivingHandshake: return "Przywitanie"
            case .transmittingPayload: return "Nadawanie"
            case .receivingPayload: return "Odbieranie"
            case .sent: return "Wysłano"
            case .receivedMessage: return "Odebrano"
            case .failed: return "Błąd"
            }
        }

        var tintColor: Color {
            switch self {
            case .idle, .checkingChannel, .channelBusy: return .blue
            case .receivingHandshake, .receivingPayload, .receivedMessage: return .yellow
            case .sendingRTS, .awaitingCTS, .transmittingPayload, .sent: return .green
            case .failed: return .red
            }
        }
    }

    private(set) var phase: Phase = .idle
    private(set) var statusText = "Gotowy do odbioru — trzymaj telefon skierowany na drugie urządzenie."
    private(set) var incomingMessages: [ReceivedMessage] = []
    private(set) var outgoingMessage: String?
    private(set) var receivingMode: SignalMode?
    private(set) var activeSendMode: SignalMode?
    private(set) var emissionProgress = 0.0
    private(set) var authorizationStatus: AVAuthorizationStatus = LightChannel.authorizationStatus

    var previewLayer: AVCaptureVideoPreviewLayer { channel.previewLayer }

    private let channel = LightChannel()
    private let operatingMode: OperatingMode
    private var loopTask: Task<Void, Never>?
    private var pendingSend: (text: String, mode: SignalMode)?
    private var isEmissionCancelled = false

    // Tunable protocol timing — best-effort defaults; likely need tuning against real hardware.
    private let maxRetries = 4
    private let channelSenseWindow: TimeInterval = 0.8
    // Control frames are deliberately short: RTS is two characters, CTS and ACK one character.
    // Longer frames proved too fragile when sent by a phone torch and sampled by another phone camera.
    private let ctsWaitTimeout: TimeInterval = 12.0
    private let boundaryGap: TimeInterval = 1.8       // delimiter between completed frames
    // After CTS the receiver has just used its own torch. Its camera may need a
    // moment to recover from glare before it can see the first payload pulse.
    private let receiverRecoveryGap: TimeInterval = 7.0
    private let payloadStartTimeout: TimeInterval = 10.0
    private let payloadSilenceTimeout: TimeInterval = 1.6
    private let boundaryDetectionThreshold: TimeInterval = 1.2 // receiver: gap this long ⇒ frame boundary
    private let idleListenTick: TimeInterval = 0.8

    init(operatingMode: OperatingMode = .standard) {
        self.operatingMode = operatingMode
    }

    func requestAccessAndStart() async {
        let granted = await LightChannel.requestAccessIfNeeded()
        authorizationStatus = LightChannel.authorizationStatus
        guard granted else { return }
        await start()
    }

    func start() async {
        guard authorizationStatus == .authorized, loopTask == nil else { return }
        loopTask = Task {
            if operatingMode == .continuousMorse {
                await self.runContinuousMorseLoop()
            } else {
                await self.runProtocolLoop()
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        loopTask = nil
        channel.stop()
    }

    func send(_ text: String, mode: SignalMode) {
        guard !text.isEmpty else { return }
        isEmissionCancelled = false
        outgoingMessage = text
        activeSendMode = mode
        emissionProgress = 0.03
        pendingSend = (text, mode)
    }

    var canStopEmission: Bool {
        switch phase {
        case .checkingChannel, .channelBusy, .sendingRTS, .awaitingCTS, .transmittingPayload:
            return true
        default:
            return false
        }
    }

    func stopEmission() {
        guard canStopEmission else { return }
        isEmissionCancelled = true
        pendingSend = nil
        channel.setTorch(false)
        phase = .idle
        statusText = "Emisję Firfly zatrzymano."
    }

    // MARK: Main loop

    private func runProtocolLoop() async {
        guard let stream = try? await channel.start() else {
            phase = .failed("Nie udało się uruchomić aparatu.")
            statusText = "Nie udało się uruchomić aparatu. Sprawdź, czy inna aplikacja nie używa kamery, i wróć do tej sekcji ponownie."
            return
        }
        let source = EdgeSource(stream)
        var lastEdge: LightEdge?

        while !Task.isCancelled {
            if let request = pendingSend {
                pendingSend = nil
                await attemptSend(request, source: source, lastEdge: &lastEdge)
                continue
            }

            phase = .idle
            statusText = "Gotowy do odbioru — trzymaj telefon skierowany na drugie urządzenie."
            lastEdge = nil

            // Listen for a 2-character RTS frame ("R" + mode tag) before touching any payload
            // decoding logic. The mode is *announced*, never guessed — this is the piece that was
            // missing before: the sender used to skip straight to blasting the raw payload, so the
            // receiver had no way to know which encoding it was looking at and had to try Firfly's
            // checksum-validated packet format first, silently falling back to an unvalidated Morse
            // guess (which always "succeeds" at producing *some* letters, just nonsense ones) on
            // every Firfly frame that didn't happen to decode cleanly.
            guard let inbound = await receiveInboundStart(source: source, lastEdge: &lastEdge) else { continue }

            if case let .message(mode) = inbound {
                phase = .receivingPayload
                receivingMode = mode
                statusText = "Wykryto \(mode.title) — odbieranie…"
                lastEdge = nil
                guard let text = await receivePayload(mode: mode, source: source, lastEdge: &lastEdge), !text.isEmpty else {
                    phase = .failed("Nie udało się odczytać wiadomości.")
                    statusText = "Wykryto sygnał, ale treść nie przeszła kontroli poprawności."
                    continue
                }
                incomingMessages.insert(ReceivedMessage(text: text, mode: mode, date: .now), at: 0)
                phase = .receivedMessage(text)
                statusText = "Odebrano: „\(text)”"
                await pause(2.0)
                continue
            }

            guard case let .handshake(rts) = inbound,
                  rts.first == "R",
                  let modeChar = rts.dropFirst().first,
                  let mode = SignalMode(controlChar: modeChar)
            else { continue }

            phase = .receivingHandshake
            receivingMode = mode
            statusText = "Wykryto \(mode.title) — oczekuję na wiadomość…"
            await source.reset()
            // Give the sender enough time to discard residual RTS edges and begin
            // listening for CTS. Without this guard interval, a valid CTS could be
            // emitted while the sender was still resetting its edge buffer.
            await pause(boundaryGap)
            await transmit(SignalEncoder.fireflyControl(for: "C"))
            await source.reset()
            lastEdge = nil

            // The sender deliberately holds the channel after CTS. Use most of
            // that window to let delayed reflections from our own torch drain,
            // then clear once more immediately before accepting payload edges.
            // Without this second reset, a late CTS reflection can become the
            // first "dot" of the incoming Morse/Firfly carrier.
            await pause(receiverRecoveryGap - 1.0)
            await source.reset()
            lastEdge = nil

            phase = .receivingPayload
            statusText = "Odbieranie…"
            guard let text = await receivePayload(mode: mode, source: source, lastEdge: &lastEdge), !text.isEmpty else {
                phase = .failed("Nie udało się odebrać sygnału.")
                statusText = "Wykryto sygnał, ale nie udało się go poprawnie zdekodować. Spróbujcie ponownie, trzymając telefony nieruchomo."
                await pause(1.5)
                continue
            }

            incomingMessages.insert(ReceivedMessage(text: text, mode: mode, date: .now), at: 0)
            phase = .receivedMessage(text)
            statusText = "Odebrano: „\(text)”"
            await source.reset()
            await transmit(SignalEncoder.fireflyControl(for: "A"))
            await pause(2.0)
        }
    }

    private func runContinuousMorseLoop() async {
        guard let stream = try? await channel.start() else {
            phase = .failed("Nie udało się uruchomić aparatu.")
            return
        }
        let source = EdgeSource(stream)
        var lastEdge: LightEdge?
        while !Task.isCancelled {
            if let request = pendingSend {
                pendingSend = nil
                await transmitContinuously(request.text)
                continue
            }
            phase = .idle
            receivingMode = .continuousMorse
            statusText = "Nasłuch ciągłego Morse’a — skieruj aparat na nadajnik."
            lastEdge = nil
            guard await receiveContinuousMarker(source: source, lastEdge: &lastEdge) else { continue }
            phase = .receivingPayload
            statusText = "Odbieranie Morse’a ciągłego…"
            lastEdge = nil
            guard let text = await receivePayload(mode: .morse, source: source, lastEdge: &lastEdge), !text.isEmpty else { continue }
            incomingMessages.insert(ReceivedMessage(text: text, mode: .continuousMorse, date: .now), at: 0)
            phase = .receivedMessage(text)
            statusText = "Odebrano: „\(text)”"
            await pause(1.0)
        }
    }

    private func attemptSend(_ request: (text: String, mode: SignalMode), source: EdgeSource, lastEdge: inout LightEdge?) async {
        defer {
            isEmissionCancelled = false
            activeSendMode = nil
            emissionProgress = 0
        }
        if request.mode == .continuousMorse {
            await transmitContinuously(request.text)
            return
        }

        guard request.mode == .morse || FirflyFrame.encode(request.text) != nil else {
            phase = .failed("Wiadomość Firfly jest za długa.")
            statusText = "Firfly obsługuje maksymalnie \(FirflyFrame.maximumPayloadLength) bajty UTF-8. Skróć wiadomość."
            return
        }

        // Standard optical links are one-way and self-synchronizing. Requiring a
        // return CTS/ACK flash made delivery depend on every single edge surviving
        // two cameras; a distinctive start marker lets the receiver join directly.
        phase = .transmittingPayload
        statusText = "Nadawanie…"
        let payload = request.mode == .morse ? SignalEncoder.morse(for: request.text) : SignalEncoder.firefly(for: request.text)
        await transmit(SignalEncoder.standardStart(for: request.mode) + payload, progressRange: 0.05...1.0)
        guard !isEmissionCancelled else { return }
        phase = .sent(request.text)
        statusText = "Nadano: „\(request.text)”"
        await pause(2.0)
        return

        for attempt in 1...maxRetries {
            guard !isEmissionCancelled else { return }

            // Handshake first: announce which encoding we're about to use and wait for the
            // receiver to be ready, before transmitting a single bit of the actual payload.
            phase = .sendingRTS
            statusText = "Łączenie (\(attempt)/\(maxRetries))…"
            emissionProgress = 0.08
            await source.reset()
            await transmit(SignalEncoder.fireflyControl(for: "R\(request.mode.controlChar)"))
            guard !isEmissionCancelled else { return }

            phase = .awaitingCTS
            statusText = "Czekam na gotowość odbiorcy…"
            emissionProgress = 0.20
            await source.reset()
            lastEdge = nil
            let cts = await receiveControlFrame(expectedLength: 1, source: source, lastEdge: &lastEdge, timeout: ctsWaitTimeout)
            guard cts == "C" else {
                phase = .failed("Nie udało się połączyć z drugim urządzeniem.")
                statusText = "Nie udało się połączyć z drugim urządzeniem. Sprawdź, czy jest w zasięgu i ma otwartą tę sekcję."
                await randomBackoff()
                continue
            }

            // The receiver resets its detector immediately after emitting CTS and
            // its camera can still be affected by the torch's glare. Leave a clear
            // recovery window before the first payload bit.
            await pause(receiverRecoveryGap)
            guard !isEmissionCancelled else { return }
            phase = .transmittingPayload
            statusText = "Nadawanie…"
            let payload = request.mode == .morse ? SignalEncoder.morse(for: request.text) : SignalEncoder.firefly(for: request.text)
            await transmit(payload, progressRange: 0.25...0.92)
            guard !isEmissionCancelled else { return }

            phase = .awaitingCTS
            statusText = "Czekam na potwierdzenie odbioru…"
            emissionProgress = 0.96
            await source.reset()
            lastEdge = nil
            let acknowledgement = await receiveControlFrame(expectedLength: 1, source: source, lastEdge: &lastEdge, timeout: ctsWaitTimeout)
            if acknowledgement == "A" {
                emissionProgress = 1
                phase = .sent(request.text)
                statusText = "Dostarczono: „\(request.text)”"
                await pause(2.0)
                return
            }

            phase = .failed("Brak potwierdzenia odbioru.")
            statusText = "Sygnał nadano, ale nie został potwierdzony przez odbiorcę."
            await randomBackoff()
        }

        phase = .failed("Nie udało się dostarczyć wiadomości.")
        statusText = "Nie udało się dostarczyć wiadomości po \(maxRetries) próbach."
        await pause(2.5)
    }

    // MARK: Frame helpers

    private enum InboundStart {
        case message(SignalMode)
        case handshake(String)
    }

    private func receiveInboundStart(source: EdgeSource, lastEdge: inout LightEdge?) async -> InboundStart? {
        var decoder = SignalDecoder(mode: .firefly, unit: SignalEncoder.controlUnit, firflyFormat: .control)
        var text = ""
        let deadline = CACurrentMediaTime() + idleListenTick

        while true {
            let remaining = deadline - CACurrentMediaTime()
            guard remaining > 0, let edge = await source.next(timeout: remaining) else { return nil }
            guard let previous = lastEdge else { lastEdge = edge; continue }
            lastEdge = edge
            let duration = edge.timestamp - previous.timestamp
            // Firfly's marker is intentionally shorter than Morse's and uses a
            // lower threshold: prolonged torch light can be split by the camera
            // exposure pipeline into two bright intervals.
            if previous.isOn, duration >= SignalEncoder.payloadUnit * 8,
               duration < SignalEncoder.payloadUnit * 12 {
                return .message(.firefly)
            }
            if previous.isOn, duration >= SignalEncoder.payloadUnit * 12 {
                return .message(.morse)
            }
            if let chunk = decoder.consume(isOn: previous.isOn, duration: duration) {
                text += chunk
                if text.count >= 2 {
                    return .handshake(String(text.prefix(2)))
                }
            }
        }
    }

    private func receiveContinuousMarker(source: EdgeSource, lastEdge: inout LightEdge?) async -> Bool {
        let deadline = CACurrentMediaTime() + idleListenTick
        while true {
            let remaining = deadline - CACurrentMediaTime()
            guard remaining > 0, let edge = await source.next(timeout: remaining) else { return false }
            guard let previous = lastEdge else { lastEdge = edge; continue }
            lastEdge = edge
            if previous.isOn, edge.timestamp - previous.timestamp >= SignalEncoder.payloadUnit * 8 {
                return true
            }
        }
    }

    private func receiveControlFrame(expectedLength: Int, source: EdgeSource, lastEdge: inout LightEdge?, timeout: TimeInterval) async -> String? {
        var decoder = SignalDecoder(mode: .firefly, unit: SignalEncoder.controlUnit, firflyFormat: .control)
        var text = ""
        let deadline = CACurrentMediaTime() + timeout

        while true {
            let remaining = deadline - CACurrentMediaTime()
            guard remaining > 0, let edge = await source.next(timeout: remaining) else { return nil }
            guard let previous = lastEdge else { lastEdge = edge; continue }
            lastEdge = edge

            let duration = edge.timestamp - previous.timestamp
            if let chunk = decoder.consume(isOn: previous.isOn, duration: duration) {
                text += chunk
                if text.count >= expectedLength {
                    return String(text.prefix(expectedLength))
                }
            }
        }
        return nil
    }

    private func receivePayload(mode: SignalMode, source: EdgeSource, lastEdge: inout LightEdge?) async -> String? {
        // Firfly packets use the already proven Morse pulse timing as their
        // physical carrier; the decoded carrier text is validated as Base32+CRC.
        let carrierMode: SignalMode = mode == .firefly ? .morse : mode
        let unit = mode == .firefly ? SignalEncoder.fireflyUnit : SignalEncoder.payloadUnit
        var decoder = SignalDecoder(mode: carrierMode, unit: unit, firflyFormat: .control)
        var text = ""

        while true {
            // Waiting for the first bit needs a much longer window than detecting
            // the end of a message. Keeping those two cases separate avoids a
            // timeout immediately after a successful CTS while still ending the
            // receive operation promptly once the sender goes quiet.
            let timeout = lastEdge == nil ? payloadStartTimeout : payloadSilenceTimeout
            guard let edge = await source.next(timeout: timeout) else { break }
            guard let previous = lastEdge else { lastEdge = edge; continue }
            lastEdge = edge

            let duration = edge.timestamp - previous.timestamp
            if let chunk = decoder.consume(isOn: previous.isOn, duration: duration) {
                text += chunk
            }
            if !previous.isOn, duration >= boundaryDetectionThreshold {
                break
            }
        }

        if let flushed = decoder.flush() {
            text += flushed
        }
        guard !text.isEmpty else { return nil }
        return mode == .firefly ? FirflyFrame.decodeCarrier(text) : text
    }

    private func transmit(_ signals: [LightSignal], progressRange: ClosedRange<Double>? = nil) async {
        for (index, signal) in signals.enumerated() {
            if Task.isCancelled || isEmissionCancelled {
                channel.setTorch(false)
                return
            }
            channel.setTorch(signal.isOn)
            await pause(signal.duration)
            if let progressRange, !signals.isEmpty {
                let fraction = Double(index + 1) / Double(signals.count)
                emissionProgress = progressRange.lowerBound + (progressRange.upperBound - progressRange.lowerBound) * fraction
            }
        }
        channel.setTorch(false)
    }

    private func transmitContinuously(_ text: String) async {
        phase = .transmittingPayload
        statusText = "Nadawanie ciągłe — zatrzymaj przyciskiem STOP."
        while !Task.isCancelled && !isEmissionCancelled {
            await transmit(SignalEncoder.continuousMorse(for: text))
            await pause(1.8)
        }
    }

    private func randomBackoff() async {
        await pause(Double.random(in: 0.6...2.2))
    }

    private func pause(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(max(seconds, 0) * 1_000_000_000))
    }
}
