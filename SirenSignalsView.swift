import SwiftUI

struct SirenSignalsShortcut: View {
    var body: some View {
        NavigationLink {
            SirenSignalsView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "waveform.badge.exclamationmark")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.red)
                    .glassBadge(tint: .red, size: 46, in: RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Sygnały syren alarmowych")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text("Zobacz schemat dźwięków i zasady reagowania")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .glassCard(tint: .red, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Otwiera ściągawkę z sygnałami syren")
    }
}

struct SirenSignalsView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SirenSignalsIntroduction()
                SirenSignalCard(
                    title: "Ogłoszenie alarmu",
                    description: "Modulowany dźwięk syreny — ton na przemian narasta i opada.",
                    duration: "3 minuty",
                    kind: .modulated,
                    tint: .red
                )
                SirenSignalCard(
                    title: "Odwołanie alarmu",
                    description: "Ciągły, jednostajny dźwięk syreny.",
                    duration: "3 minuty",
                    kind: .continuous,
                    tint: .green
                )
                SirenResponseGuide()
                SirenExerciseNote()
            }
            .padding()
        }
        .navigationTitle("Sygnały syren")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct SirenSignalsIntroduction: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Jak rozpoznać alarm?", systemImage: "waveform.badge.exclamationmark")
                .font(.title2.weight(.bold))
                .foregroundStyle(.red)

            Text("W Polsce alarm dla ludności cywilnej ogłasza dźwięk modulowany, a odwołuje dźwięk ciągły. Oba sygnały trwają trzy minuty.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SirenSignalCard: View {
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    let duration: LocalizedStringResource
    let kind: SirenWaveform.Kind
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: kind == .modulated ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(tint)
                    .glassBadge(tint: tint, size: 44, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline)
                    Text(duration)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(tint)
                }

                Spacer(minLength: 0)
            }

            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SirenWaveform(kind: kind)
                .stroke(tint, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(height: 72)
                .padding(.horizontal, 4)
                .accessibilityHidden(true)

            HStack {
                Text("0 min")
                Spacer()
                Text("3 min")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.secondary)
        }
        .padding(16)
        .glassCard(tint: tint, cornerRadius: 18)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue("\(description) Czas trwania: \(duration).")
    }
}

private struct SirenResponseGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Co zrobić po usłyszeniu alarmu", systemImage: "figure.walk.motion.trianglebadge.exclamationmark")
                .font(.headline)

            SirenResponseRow(number: "1", text: "Zachowaj spokój i sprawdź, czy sygnał nie jest częścią zapowiedzianych ćwiczeń.")
            SirenResponseRow(number: "2", text: "Włącz radio, telewizję lub sprawdź oficjalne komunikaty RCB i lokalnych władz.")
            SirenResponseRow(number: "3", text: "Postępuj zgodnie z przekazanymi instrukcjami dla Twojego obszaru.")
        }
        .padding(16)
        .glassCard(tint: .orange, cornerRadius: 18)
    }
}

private struct SirenResponseRow: View {
    let number: String
    let text: LocalizedStringResource

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(.orange, in: .circle)

            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct SirenExerciseNote: View {
    var body: some View {
        Label {
            Text("Sygnał ćwiczebny to ciągły dźwięk trwający 1 minutę. Ćwiczenia są ogłaszane z wyprzedzeniem w oficjalnych komunikatach.")
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.blue)
        }
        .padding(14)
        .glassCard(tint: .blue, cornerRadius: 16)
    }
}

private struct SirenWaveform: Shape {
    enum Kind {
        case modulated
        case continuous
    }

    let kind: Kind

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midY = rect.midY
        let horizontalInset: CGFloat = 2
        let width = max(rect.width - horizontalInset * 2, 1)

        path.move(to: CGPoint(x: horizontalInset, y: midY))

        switch kind {
        case .continuous:
            path.addLine(to: CGPoint(x: rect.maxX - horizontalInset, y: midY))
        case .modulated:
            let sampleCount = 120
            let maximumAmplitude = rect.height * 0.38

            for sample in 1...sampleCount {
                let progress = CGFloat(sample) / CGFloat(sampleCount)
                let x = horizontalInset + width * progress
                let modulation = (sin(progress * .pi * 6 - .pi / 2) + 1) / 2
                let carrier = sin(progress * .pi * 28)
                let y = midY + carrier * maximumAmplitude * (0.18 + modulation * 0.82)
                path.addLine(to: CGPoint(x: x, y: y))
            }
        }

        return path
    }
}

#Preview {
    NavigationStack {
        SirenSignalsView()
    }
}
