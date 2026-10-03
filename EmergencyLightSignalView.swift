import SwiftUI
import AVFoundation

struct LightSignalView: View {
    @State private var coordinator = LightSessionCoordinator(operatingMode: .continuousMorse)

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                EmergencyLightHeader()

                switch coordinator.authorizationStatus {
                case .authorized:
                    EmergencyLightStatusCard(
                        previewLayer: coordinator.previewLayer,
                        phase: coordinator.phase,
                        statusText: coordinator.statusText
                    )

                    if coordinator.canStopEmission {
                        EmergencyLightStopButton {
                            coordinator.stopEmission()
                        }
                    } else {
                        EmergencyLightPresets { payload in
                            coordinator.send(payload, mode: .continuousMorse)
                        }
                    }

                    EmergencyLightReceiver(messages: coordinator.incomingMessages)
                case .denied, .restricted:
                    LightPermissionCard(kind: .denied) {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                default:
                    LightPermissionCard(kind: .request) {
                        Task {
                            await coordinator.requestAccessAndStart()
                        }
                    }
                }

                ExperimentalLightLink()
            }
            .padding()
        }
        .navigationTitle("Sygnały świetlne")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await coordinator.start()
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            coordinator.stop()
        }
    }
}

private struct EmergencyLightHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Awaryjny sygnał światłem", systemImage: "flashlight.on.fill")
                .font(.title2.weight(.bold))
                .foregroundStyle(.yellow)

            Text("Wybierz krótki komunikat. Latarka będzie powtarzać go kodem Morse’a aż do naciśnięcia STOP.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("To funkcja pomocnicza — nie zastępuje numeru 112 ani łączności ze służbami.", systemImage: "exclamationmark.triangle.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.orange)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EmergencyLightPresets: View {
    private let presets = EmergencyLightPreset.defaults
    let send: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nadaj komunikat")
                .font(.headline)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(presets) { preset in
                    Button {
                        send(preset.payload)
                    } label: {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: preset.icon)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(preset.color)

                            Text(preset.title)
                                .font(.headline)
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)

                            Text("Nadaje: (preset.payload)")
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
                        .padding(14)
                        .glassCard(tint: preset.color, cornerRadius: 18, interactive: true)
                    }
                    .buttonStyle(.tilePress)
                    .accessibilityHint("Rozpoczyna powtarzanie komunikatu światłem do czasu naciśnięcia STOP")
                }
            }
        }
    }
}

private struct EmergencyLightStopButton: View {
    let stop: () -> Void

    var body: some View {
        Button(role: .destructive, action: stop) {
            HStack(spacing: 12) {
                Image(systemName: "stop.fill")
                    .font(.title2.weight(.bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("STOP")
                        .font(.headline)
                    Text("Zatrzymaj nadawanie")
                        .font(.caption)
                }
                Spacer()
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(.red.gradient, in: .rect(cornerRadius: 18))
            .shadow(color: .red.opacity(0.25), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Natychmiast wyłącza latarkę")
    }
}

private struct EmergencyLightStatusCard: View {
    let previewLayer: AVCaptureVideoPreviewLayer
    let phase: LightSessionCoordinator.Phase
    let statusText: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            CameraPreviewView(previewLayer: previewLayer)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(phase.tintColor)
                        .frame(width: 8, height: 8)
                    Text(phase.label)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(phase.tintColor)
                }

                Text(statusText)
                    .font(.subheadline.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .glassCard(tint: phase.tintColor, cornerRadius: 18)
        .accessibilityElement(children: .combine)
    }
}

private struct EmergencyLightReceiver: View {
    let messages: [ReceivedMessage]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Odbiór", systemImage: "camera.viewfinder")
                .font(.headline)

            if messages.isEmpty {
                Text("Aparat nasłuchuje automatycznie. Skieruj go na latarkę drugiego telefonu i trzymaj urządzenie nieruchomo.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .glassCard(tint: .blue, cornerRadius: 16)
            } else {
                ForEach(messages) { message in
                    HStack(spacing: 12) {
                        Image(systemName: "waveform.badge.checkmark")
                            .font(.title3)
                            .foregroundStyle(.green)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(message.text)
                                .font(.headline)
                            Text(message.date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(14)
                    .glassCard(tint: .green, cornerRadius: 16)
                }
            }
        }
    }
}

private struct ExperimentalLightLink: View {
    var body: some View {
        NavigationLink {
            ExperimentalLightSignalView()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "testtube.2")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.purple)
                    .frame(width: 40, height: 40)
                    .glassEffect(.regular.tint(.purple.opacity(0.2)), in: .circle)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Eksperymentalne")
                        .font(.headline)
                    Text("Własny tekst, Firfly i transmisja z automatycznym odbiorem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .glassCard(tint: .purple, cornerRadius: 16, interactive: true)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.tilePress)
    }
}

private struct LightPermissionCard: View {
    enum Kind {
        case request
        case denied
    }

    let kind: Kind
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: kind == .request ? "camera.fill" : "camera.fill.badge.ellipsis")
                .font(.system(size: 38))
                .foregroundStyle(kind == .request ? .yellow : .red)

            Text(kind == .request
                 ? "Aparat jest potrzebny do odbierania i dekodowania sygnałów świetlnych."
                 : "Dostęp do aparatu jest zablokowany. Włącz go w Ustawieniach, aby korzystać z odbioru.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(kind == .request ? "Zezwól na dostęp" : "Otwórz Ustawienia", action: action)
                .buttonStyle(.glassProminent)
                .tint(kind == .request ? .yellow : .red)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .glassCard(tint: kind == .request ? .yellow : .red, cornerRadius: 18)
    }
}

private struct EmergencyLightPreset: Identifiable {
    let id: String
    let title: LocalizedStringResource
    let payload: String
    let icon: String
    let color: Color

    static let defaults: [EmergencyLightPreset] = [
        EmergencyLightPreset(
            id: "sos",
            title: "SOS — zagrożenie życia",
            payload: "SOS",
            icon: "sos.circle.fill",
            color: .red
        ),
        EmergencyLightPreset(
            id: "help",
            title: "Potrzebuję pomocy",
            payload: "POMOC",
            icon: "hand.raised.fill",
            color: .orange
        ),
        EmergencyLightPreset(
            id: "medic",
            title: "Pomoc medyczna",
            payload: "MEDYK",
            icon: "cross.case.fill",
            color: .green
        ),
        EmergencyLightPreset(
            id: "location",
            title: "Jestem tutaj",
            payload: "TU JESTEM",
            icon: "location.fill",
            color: .blue
        )
    ]
}

#Preview {
    NavigationStack {
        LightSignalView()
    }
}
