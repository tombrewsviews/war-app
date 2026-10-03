import SwiftUI

struct LightSignalTutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private struct Step {
        let icon: String
        let title: String
        let text: String
    }

    private let steps: [Step] = [
        Step(
            icon: "text.cursor",
            title: "1. Wpisz komunikat",
            text: "Wpisz krótki tekst, np. SOS, i wybierz kod: Morse'a albo Firfly."
        ),
        Step(
            icon: "flashlight.on.fill",
            title: "2. Skieruj lampę na drugi telefon",
            text: "Ustaw telefony tak, by lampa błyskowa jednego była w polu widzenia aparatu drugiego – ok. 0,5–2 m, najlepiej w ciemnym miejscu."
        ),
        Step(
            icon: "antenna.radiowaves.left.and.right",
            title: "3. Urządzenia same się dogadają",
            text: "Telefony \"przywitają się\" światłem i same ustalą, które nadaje, a które odbiera. Nie musisz nic klikać na urządzeniu odbierającym."
        ),
        Step(
            icon: "checkmark.circle.fill",
            title: "4. Odczytaj wynik",
            text: "Trzymaj telefony nieruchomo. Nadawca zobaczy potwierdzenie wysłania, odbiorca — odebraną wiadomość na liście poniżej."
        )
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(steps.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        Image(systemName: steps[index].icon)
                            .font(.system(size: 64))
                            .foregroundStyle(.yellow)
                        Text(steps[index].title)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.center)
                        Text(steps[index].text)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                    .padding()
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))

            Button(page == steps.count - 1 ? "Rozumiem, zaczynajmy" : "Dalej") {
                if page == steps.count - 1 {
                    dismiss()
                } else {
                    withAnimation { page += 1 }
                }
            }
            .buttonStyle(.glassProminent)
            .tint(.yellow)
            .padding(.horizontal)
            .padding(.bottom)
        }
        .padding(.top)
    }
}

#Preview {
    LightSignalTutorialView()
}
