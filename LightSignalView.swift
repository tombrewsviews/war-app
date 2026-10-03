import SwiftUI
import AVFoundation

// MARK: - Signal mode

enum SignalMode: String, Identifiable, CaseIterable, Sendable {
    case morse
    case firefly
    case continuousMorse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morse: return "Kod Morse'a"
        case .firefly: return "Kod Firfly"
        case .continuousMorse: return "Morse ciągły"
        }
    }

    var subtitle: String {
        switch self {
        case .morse: return "Klasyczny alfabet Morse'a – kropki i kreski"
        case .firefly: return "Odporny pakiet UTF-8 z kontrolą błędów"
        case .continuousMorse: return "Powtarza komunikat bez łączenia — zatrzymaj przyciskiem STOP"
        }
    }

    var icon: String {
        switch self {
        case .morse: return "dot.radiowaves.left.and.right"
        case .firefly: return "sparkles"
        case .continuousMorse: return "repeat.circle.fill"
        }
    }
}

// MARK: - Encoding

struct LightSignal: Sendable {
    let isOn: Bool
    let duration: TimeInterval
}

enum SignalEncoder {
    /// Timing for the human-facing payload (Morse/Świetlik message) — slower, so it stays legible to a trained eye.
    static let payloadUnit: TimeInterval = 0.15
    static let fireflyUnit: TimeInterval = 0.10
    /// Timing for machine-only handshake frames (RTS/CTS/EOT) — faster, since nobody needs to read these by eye.
    static let controlUnit: TimeInterval = 0.15

    static let morseTable: [Character: String] = [
        "a": ".-", "b": "-...", "c": "-.-.", "d": "-..", "e": ".", "f": "..-.",
        "g": "--.", "h": "....", "i": "..", "j": ".---", "k": "-.-", "l": ".-..",
        "m": "--", "n": "-.", "o": "---", "p": ".--.", "q": "--.-", "r": ".-.",
        "s": "...", "t": "-", "u": "..-", "v": "...-", "w": ".--", "x": "-..-",
        "y": "-.--", "z": "--..",
        "0": "-----", "1": ".----", "2": "..---", "3": "...--", "4": "....-",
        "5": ".....", "6": "-....", "7": "--...", "8": "---..", "9": "----."
    ]

    static func morse(for text: String, unit: TimeInterval = payloadUnit) -> [LightSignal] {
        let normalized = text
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "pl_PL"))
            .lowercased()

        var signals: [LightSignal] = []
        let words = normalized.split(separator: " ", omittingEmptySubsequences: true)

        for (wordIndex, word) in words.enumerated() {
            let letters = Array(word)
            for (charIndex, char) in letters.enumerated() {
                guard let code = morseTable[char] else { continue }
                for (symbolIndex, symbol) in code.enumerated() {
                    signals.append(LightSignal(isOn: true, duration: symbol == "." ? unit : unit * 3))
                    if symbolIndex < code.count - 1 {
                        signals.append(LightSignal(isOn: false, duration: unit))
                    }
                }
                if charIndex < letters.count - 1 {
                    signals.append(LightSignal(isOn: false, duration: unit * 3))
                }
            }
            if wordIndex < words.count - 1 {
                signals.append(LightSignal(isOn: false, duration: unit * 7))
            }
        }

        return signals
    }

    static func continuousMorse(for text: String, unit: TimeInterval = payloadUnit) -> [LightSignal] {
        let marker = [
            LightSignal(isOn: true, duration: unit * 10),
            LightSignal(isOn: false, duration: unit * 3)
        ]
        return marker + morse(for: text, unit: unit)
    }

    static func standardStart(for mode: SignalMode, unit: TimeInterval = payloadUnit) -> [LightSignal] {
        let multiplier: TimeInterval = mode == .firefly ? 10 : 14
        return [
            LightSignal(isOn: true, duration: unit * multiplier),
            LightSignal(isOn: false, duration: unit * 3)
        ]
    }

    /// Firfly payload: framed UTF-8 bytes with a version, length, and CRC-16 checksum.
    /// The packet uses Morse timing as its optical carrier — proven robust on phone cameras —
    /// while Firfly itself remains a compact Base32 UTF-8 frame with CRC validation.
    static func firefly(for text: String, unit: TimeInterval = fireflyUnit) -> [LightSignal] {
        morse(for: FirflyFrame.encodeCarrier(text) ?? "", unit: unit)
    }

    /// The handshake uses fixed ASCII control frames; it intentionally remains separate from Firfly payload packets.
    static func fireflyControl(for text: String, unit: TimeInterval = controlUnit) -> [LightSignal] {
        let bytes = text.utf8.map { $0 & 0x7F }
        // A pulse which is longer than every data bit is a physical start marker.
        // It lets the receiver discard any spurious edge and align to the next bit.
        let startMarker = [
            LightSignal(isOn: true, duration: unit * 6),
            LightSignal(isOn: false, duration: unit * 3)
        ]
        let data = bytes.flatMap { byte in
            (0..<7).reversed().flatMap { bitIndex in
                let bit = (byte >> bitIndex) & 1
                return [
                    LightSignal(isOn: true, duration: bit == 1 ? unit * 3 : unit),
                    LightSignal(isOn: false, duration: unit)
                ]
            }
        }
        return startMarker + data
    }

    private static func fireflyBytes(_ bytes: [UInt8], unit: TimeInterval) -> [LightSignal] {
        bytes.flatMap { byte in
            (0..<8).reversed().flatMap { bitIndex in
                let bit = (byte >> bitIndex) & 1
                return [
                    LightSignal(isOn: true, duration: bit == 1 ? unit * 3 : unit),
                    LightSignal(isOn: false, duration: unit)
                ]
            }
        }
    }
}

enum FirflyFrame {
    static let maximumPayloadLength = 24
    private static let preamble: [UInt8] = [0xD5, 0x2A]
    private static let version: UInt8 = 1

    static func encode(_ text: String) -> [UInt8]? {
        let payload = Array(text.utf8)
        guard !payload.isEmpty, payload.count <= maximumPayloadLength else { return nil }

        let body = preamble + [version, UInt8(payload.count)] + payload
        let checksum = crc16(body)
        return body + [UInt8(checksum >> 8), UInt8(checksum & 0xFF)]
    }

    static func decode(_ bytes: [UInt8]) -> String? {
        let minimumLength = preamble.count + 1 + 1 + 2
        guard bytes.count >= minimumLength else { return nil }

        for start in bytes.indices where bytes.dropFirst(start).starts(with: preamble) {
            let headerEnd = start + preamble.count + 2
            guard bytes.count >= headerEnd else { continue }
            guard bytes[start + preamble.count] == version else { continue }

            let payloadLength = Int(bytes[start + preamble.count + 1])
            guard payloadLength <= maximumPayloadLength else { continue }
            let frameLength = preamble.count + 2 + payloadLength + 2
            guard bytes.count >= start + frameLength else { continue }

            let frame = Array(bytes[start..<(start + frameLength)])
            let body = Array(frame.dropLast(2))
            let receivedChecksum = UInt16(frame[frame.count - 2]) << 8 | UInt16(frame[frame.count - 1])
            guard crc16(body) == receivedChecksum else { continue }

            let payloadStart = preamble.count + 2
            let payload = frame[payloadStart..<(payloadStart + payloadLength)]
            return String(bytes: payload, encoding: .utf8)
        }
        return nil
    }

    static func encodeCarrier(_ text: String) -> String? {
        encode(text).map(base32Encode)
    }

    static func decodeCarrier(_ carrier: String) -> String? {
        guard let bytes = base32Decode(carrier) else { return nil }
        return decode(bytes)
    }

    nonisolated private static let base32Alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ234567")

    nonisolated private static func base32Encode(_ bytes: [UInt8]) -> String {
        var value = 0
        var bitCount = 0
        var result = ""
        for byte in bytes {
            value = (value << 8) | Int(byte)
            bitCount += 8
            while bitCount >= 5 {
                bitCount -= 5
                result.append(base32Alphabet[(value >> bitCount) & 0x1F])
            }
        }
        if bitCount > 0 {
            result.append(base32Alphabet[(value << (5 - bitCount)) & 0x1F])
        }
        return result
    }

    nonisolated private static func base32Decode(_ text: String) -> [UInt8]? {
        var value = 0
        var bitCount = 0
        var bytes: [UInt8] = []
        for character in text.uppercased() {
            guard let index = base32Alphabet.firstIndex(of: character) else { return nil }
            value = (value << 5) | index
            bitCount += 5
            while bitCount >= 8 {
                bitCount -= 8
                bytes.append(UInt8((value >> bitCount) & 0xFF))
            }
        }
        return bytes
    }

    private static func crc16(_ bytes: [UInt8]) -> UInt16 {
        bytes.reduce(UInt16(0xFFFF)) { checksum, byte in
            var value = checksum ^ (UInt16(byte) << 8)
            for _ in 0..<8 {
                value = value & 0x8000 == 0 ? value << 1 : (value << 1) ^ 0x1021
            }
            return value
        }
    }
}

// MARK: - Main screen

struct ExperimentalLightSignalView: View {
    @State private var message: String = ""
    @State private var coordinator = LightSessionCoordinator()
    @FocusState private var isInputFocused: Bool
    @AppStorage("hasSeenLightSignalTutorial") private var hasSeenTutorial = false
    @State private var showTutorial = false

    private var trimmedMessage: String {
        message.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isBusy: Bool {
        switch coordinator.phase {
        case .idle: return false
        default: return true
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                switch coordinator.authorizationStatus {
                case .authorized:
                    SignalStatusCard(
                        previewLayer: coordinator.previewLayer,
                        phase: coordinator.phase,
                        statusText: coordinator.statusText,
                        outgoingMessage: coordinator.outgoingMessage,
                        receivingMode: coordinator.receivingMode
                    )
                    NavigationLink {
                        ContinuousMorseView()
                    } label: {
                        Label("Morse ciągły", systemImage: "repeat.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    inputField
                    sendButtons
                    stopEmissionButton
                    incomingMessagesSection
                case .denied, .restricted:
                    permissionDeniedCard
                default:
                    permissionRequestCard
                }
            }
            .padding()
        }
        .navigationTitle("Eksperymentalne")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showTutorial = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .task {
            if !hasSeenTutorial {
                showTutorial = true
            }
        }
        .task {
            // Starts the camera/torch loop immediately when permission was already granted in a
            // previous session — `requestAccessAndStart()` (below) only covers the first-time grant.
            await coordinator.start()
        }
        .onAppear {
            // A light link depends on the camera preview remaining active. Restore
            // the app default when this screen is no longer visible.
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .sheet(isPresented: $showTutorial, onDismiss: { hasSeenTutorial = true }) {
            LightSignalTutorialView()
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            coordinator.stop()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Sygnalizacja świetlna")
                .font(.largeTitle.weight(.bold))
            Text("Wpisz krótki komunikat i wyślij go lampą aparatu – kodem Morse'a albo naszym kodem Firfly. Urządzenia same się \"przywitają\" światłem i ustalą, kto nadaje, a kto odbiera.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionRequestCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill")
                .font(.system(size: 40))
                .foregroundStyle(.yellow)
            Text("Ta funkcja potrzebuje dostępu do aparatu, by odbierać i dekodować sygnały świetlne z innych urządzeń.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Zezwól na dostęp do aparatu") {
                Task { await coordinator.requestAccessAndStart() }
            }
            .buttonStyle(.glassProminent)
            .tint(.yellow)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard(tint: .yellow, cornerRadius: 16)
    }

    private var permissionDeniedCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "camera.fill.badge.ellipsis")
                .font(.system(size: 40))
                .foregroundStyle(.red)
            Text("Dostęp do aparatu jest zablokowany. Włącz go w Ustawieniach, aby móc nadawać i odbierać sygnały świetlne.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Otwórz Ustawienia") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.red)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard(tint: .red, cornerRadius: 16)
    }

    private var statusCard: some View {
        HStack(alignment: .top, spacing: 14) {
            CameraPreviewView(previewLayer: coordinator.previewLayer)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(coordinator.phase.tintColor)
                        .frame(width: 8, height: 8)
                    Text(coordinator.phase.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(coordinator.statusText)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                if let outgoingMessage = coordinator.outgoingMessage {
                    Divider()
                        .padding(.vertical, 2)

                    Text("Nadawany komunikat")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(outgoingMessage)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }

    private var inputField: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Treść sygnału")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            TextField("np. SOS lub Ciszej, żołnierze nadchodzą", text: $message, axis: .vertical)
                .focused($isInputFocused)
                .lineLimit(1...3)
                .textInputAutocapitalization(.characters)
                .padding(12)
                .glassCard(cornerRadius: 12)
        }
    }

    private var sendButtons: some View {
        VStack(spacing: 14) {
            ForEach([SignalMode.morse, .firefly]) { mode in
                SignalSendButton(
                    mode: mode,
                    isActive: coordinator.activeSendMode == mode,
                    progress: coordinator.emissionProgress
                ) {
                    isInputFocused = false
                    coordinator.send(trimmedMessage, mode: mode)
                }
                .disabled(trimmedMessage.isEmpty || isBusy)
                .opacity((trimmedMessage.isEmpty || isBusy) ? 0.5 : 1)
            }
        }
    }

    @ViewBuilder
    private var stopEmissionButton: some View {
        if coordinator.canStopEmission {
            HStack {
                Spacer()
                Button(role: .destructive) {
                    coordinator.stopEmission()
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: "stop.fill")
                            .font(.headline.weight(.bold))
                        Text("STOP")
                            .font(.caption2.weight(.black))
                    }
                    .foregroundStyle(.white)
                    .frame(width: 58, height: 58)
                    .background(Circle().fill(.red.gradient))
                    .shadow(color: .red.opacity(0.28), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zatrzymaj emisję")
                .accessibilityHint("Natychmiast wyłącza latarkę i anuluje bieżącą transmisję")
            }
        }
    }

    private var incomingMessagesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Odebrane sygnały")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if coordinator.incomingMessages.isEmpty {
                Text("Tu pojawią się sygnały odebrane od innych urządzeń. Nie musisz nic klikać — aplikacja odbiera automatycznie w tle.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(coordinator.incomingMessages) { received in
                        HStack(spacing: 10) {
                            Image(systemName: received.mode.icon)
                                .foregroundStyle(.blue)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(received.text)
                                    .font(.subheadline.weight(.semibold))
                                Text(received.mode.title)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .glassCard(tint: .blue, cornerRadius: 12)
                    }
                }
            }
        }
    }
}

private struct ContinuousMorseView: View {
    @State private var message = ""
    @State private var coordinator = LightSessionCoordinator(operatingMode: .continuousMorse)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Morse ciągły")
                    .font(.title.bold())
                Text("Ten ekran działa bez handshake’u. Nadajnik powtarza komunikat do STOP, a odbiornik może dołączyć w dowolnym momencie.")
                    .foregroundStyle(.secondary)
                SignalStatusCard(previewLayer: coordinator.previewLayer, phase: coordinator.phase, statusText: coordinator.statusText, outgoingMessage: coordinator.outgoingMessage, receivingMode: coordinator.receivingMode)
                TextField("Treść komunikatu", text: $message, axis: .vertical)
                    .lineLimit(1...3)
                    .padding(12)
                    .glassCard(cornerRadius: 12)
                Button("Rozpocznij nadawanie ciągłe") {
                    coordinator.send(message.trimmingCharacters(in: .whitespacesAndNewlines), mode: .continuousMorse)
                }
                .buttonStyle(.glassProminent)
                .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || coordinator.canStopEmission)
                if coordinator.canStopEmission {
                    Button("STOP", role: .destructive) { coordinator.stopEmission() }
                        .buttonStyle(.glassProminent)
                }
                IncomingMessagesList(messages: coordinator.incomingMessages)
            }
            .padding()
        }
        .navigationTitle("Morse ciągły")
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false; coordinator.stop() }
        .task { await coordinator.start() }
    }
}

private struct IncomingMessagesList: View {
    let messages: [ReceivedMessage]
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Odebrane komunikaty").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(messages) { message in
                Text(message.text).padding(10).frame(maxWidth: .infinity, alignment: .leading).glassCard(tint: .blue, cornerRadius: 12)
            }
        }
    }
}

private struct SignalStatusCard: View {
    let previewLayer: AVCaptureVideoPreviewLayer
    let phase: LightSessionCoordinator.Phase
    let statusText: String
    let outgoingMessage: String?
    let receivingMode: SignalMode?

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CameraPreviewView(previewLayer: previewLayer)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(phase.tintColor)
                        .frame(width: 8, height: 8)
                    Text(phase.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)

                if let receivingMode {
                    Label("Tryb odbioru: \(receivingMode.title)", systemImage: receivingMode.icon)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let outgoingMessage {
                    Divider().padding(.vertical, 2)
                    Text("Nadawany komunikat")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(outgoingMessage)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassCard(cornerRadius: 16)
    }
}

private struct SignalSendButton: View {
    let mode: SignalMode
    let isActive: Bool
    let progress: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .leading) {
                GeometryReader { proxy in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.green.opacity(0.25))
                        .frame(width: isActive ? proxy.size.width * max(0.08, progress) : 0)
                        .animation(.easeOut(duration: 0.15), value: progress)
                }

                HStack(spacing: 14) {
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .frame(width: 34)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(mode.title).font(.headline)
                        Text(isActive ? "Łączenie lub nadawanie…" : mode.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: isActive ? "waveform" : "chevron.right")
                        .foregroundStyle(isActive ? .green : .secondary)
                }
                .padding()
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .glassCard(tint: .yellow, cornerRadius: 16)
            .foregroundStyle(.primary)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.tilePress)
    }
}

// MARK: - Camera preview

struct CameraPreviewView: UIViewRepresentable {
    let previewLayer: AVCaptureVideoPreviewLayer

    func makeUIView(context: Context) -> PreviewContainerView {
        previewLayer.videoGravity = .resizeAspectFill
        let view = PreviewContainerView()
        view.previewLayer = previewLayer
        view.layer.addSublayer(previewLayer)
        return view
    }

    func updateUIView(_ uiView: PreviewContainerView, context: Context) {
        if uiView.previewLayer !== previewLayer {
            uiView.previewLayer?.removeFromSuperlayer()
            uiView.layer.addSublayer(previewLayer)
            uiView.previewLayer = previewLayer
        }
    }

    final class PreviewContainerView: UIView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layoutSubviews() {
            super.layoutSubviews()
            previewLayer?.frame = bounds
        }
    }
}

#Preview {
    NavigationStack {
        ExperimentalLightSignalView()
    }
}
