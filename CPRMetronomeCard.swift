import SwiftUI

/// The flagship differentiator for this section: most first-aid apps just tell you the target rate
/// in text — this one counts it out loud and visually, with a distinct cue for the 2-breath pause
/// after every 30 compressions, so you don't have to keep count yourself mid-emergency.
struct CPRMetronomeCard: View {
    @State private var metronome = CPRMetronome()
    @State private var pulse = false

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Metronom RKO")
                    .font(.headline)
                Spacer()
                Text("110/min")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ZStack {
                Circle()
                    .fill(Color.pink.opacity(pulse ? 0.35 : 0.15))
                    .frame(width: 130, height: 130)
                    .scaleEffect(pulse ? 1.08 : 1.0)
                    .animation(.easeOut(duration: 0.12), value: pulse)

                VStack(spacing: 2) {
                    Text(phaseTitle)
                        .font(.system(size: 30, weight: .bold))
                        .contentTransition(.numericText())
                    Text(phaseSubtitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .contentTransition(.opacity)
                }
                .animation(.snappy, value: metronome.phase)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)

            Button {
                withAnimation(.snappy) {
                    if metronome.isRunning {
                        metronome.stop()
                    } else {
                        metronome.start()
                    }
                }
            } label: {
                Label(metronome.isRunning ? "Zatrzymaj" : "Start RKO", systemImage: metronome.isRunning ? "stop.fill" : "play.fill")
                    .contentTransition(.symbolEffect(.replace))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(metronome.isRunning ? .red : .pink)
            .animation(.default, value: metronome.isRunning)

            Text("Dźwięk i pulsowanie w tempie uciśnięć (110/min), z osobnym sygnałem na 2 oddechy po każdych 30 uciśnięciach — nie musisz liczyć samodzielnie.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .glassCard(tint: .pink, cornerRadius: 16)
        .onChange(of: metronome.phase) {
            pulse = true
            Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                pulse = false
            }
        }
        .onDisappear {
            metronome.stop()
        }
    }

    private var phaseTitle: String {
        switch metronome.phase {
        case .stopped: return "—"
        case .compressions(let count): return "\(count)/30"
        case .breaths: return "2 oddechy"
        }
    }

    private var phaseSubtitle: String {
        switch metronome.phase {
        case .stopped: return "Naciśnij Start"
        case .compressions: return "Uciskaj w rytm"
        case .breaths: return "Teraz!"
        }
    }
}

#Preview {
    CPRMetronomeCard()
        .padding()
}
