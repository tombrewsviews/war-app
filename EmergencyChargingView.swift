import SwiftUI

struct EmergencyChargingView: View {
    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "battery.100.bolt",
            title: "Naładowany power bank — zawczasu",
            description: "Najpewniejsze źródło energii. Trzymaj co najmniej jeden power bank zawsze naładowany w domu i drugi w plecaku ewakuacyjnym."
        ),
        FirstAidStep(
            icon: "sun.max.fill",
            title: "Panel słoneczny",
            description: "Małe panele solarne (turystyczne) realnie ładują telefon w ciągu dnia. Wymaga bezpośredniego słońca i cierpliwości — kilka godzin na pełne naładowanie."
        ),
        FirstAidStep(
            icon: "hand.raised.fill",
            title: "Ładowarka korbowa (dynamo)",
            description: "Ręczna korba generuje prąd niezależnie od pogody czy pory dnia. Wolniejsza niż panel słoneczny, ale działa zawsze — warto mieć jedną w zapasie."
        ),
        FirstAidStep(
            icon: "car.fill",
            title: "Gniazdo USB w samochodzie",
            description: "Jeśli masz dostęp do auta z paliwem, uruchom silnik i naładuj telefon przez port USB lub zapalniczkę. Nie zostawiaj silnika pracującego bez potrzeby."
        ),
        FirstAidStep(
            icon: "battery.25",
            title: "Oszczędzanie baterii",
            description: "Zmniejsz jasność ekranu, włącz tryb samolotowy i włączaj sieć tylko na chwilę do sprawdzenia wiadomości, wyłącz nieużywane aplikacje w tle. To wydłuży czas działania telefonu wielokrotnie."
        ),
        FirstAidStep(
            icon: "lightbulb.fill",
            title: "Ciekawostka: cytryna, sól i kabel",
            description: "Cytryna, ziemniak albo słona woda z dwoma różnymi metalami (np. cynk i miedź) tworzą prawdziwe ogniwo galwaniczne — ale generują pojedyncze mikroamperów. To fizycznie za mało, by naładować telefon (potrzeba tysięcy razy więcej prądu). Realnie wystarczy co najwyżej podtrzymać diodę LED lub mały zegarek kwarcowy na chwilę."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .yellow)
                    }
                }

                FirstAidWarningBox(text: "Nie licz na domowe „baterie” z owoców czy warzyw jako realne źródło ładowania w kryzysie — przygotuj prawdziwy power bank zawczasu.")
            }
            .padding()
        }
        .navigationTitle("Awaryjne ładowanie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.yellow)
                .glassBadge(tint: .yellow, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Awaryjne ładowanie")
                .font(.title.weight(.bold))
            Text("Telefon to dostęp do alertów, mapy i komunikacji Mesh — warto mieć plan na jego zasilanie bez prądu z sieci.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        EmergencyChargingView()
    }
}
