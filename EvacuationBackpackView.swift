import SwiftUI

struct EvacuationBackpackView: View {
    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "doc.text.fill",
            title: "Dokumenty",
            description: "Dowód osobisty, paszport, akty urodzenia, polisy ubezpieczeniowe. Zrób też cyfrowe kopie (zdjęcia lub skany) na zaszyfrowanym pendrive albo w chmurze dostępnej offline."
        ),
        FirstAidStep(
            icon: "banknote.fill",
            title: "Gotówka w małych nominałach",
            description: "Płatności elektroniczne mogą nie działać bez prądu i internetu. Drobne banknoty łatwiej wykorzystać niż duże."
        ),
        FirstAidStep(
            icon: "waterbottle.fill",
            title: "Woda i jedzenie na 72 godziny",
            description: "Minimum 2 litry wody na osobę dziennie. Żywność niewymagająca gotowania: batony energetyczne, konserwy z otwieraczem, żywność liofilizowana."
        ),
        FirstAidStep(
            icon: "cross.case.fill",
            title: "Apteczka i leki",
            description: "Podstawowa apteczka pierwszej pomocy plus zapas własnych leków na receptę na minimum kilka dni. Sprawdzaj daty ważności."
        ),
        FirstAidStep(
            icon: "flashlight.on.fill",
            title: "Latarka, power bank, radio",
            description: "Latarka czołowa (ręce wolne), naładowany power bank, radio na baterie lub korbowe do odbioru komunikatów, gdy nie ma internetu."
        ),
        FirstAidStep(
            icon: "tshirt.fill",
            title: "Odzież na zmianę",
            description: "Komplet ciepłej odzieży niezależnie od pory roku, solidne buty do chodzenia, peleryna przeciwdeszczowa."
        ),
        FirstAidStep(
            icon: "person.2.fill",
            title: "Lista kontaktów na papierze",
            description: "Telefon może się rozładować lub zgubić. Zapisz na kartce najważniejsze numery: rodzina, lekarz, punkt zbiórki."
        ),
        FirstAidStep(
            icon: "arrow.triangle.2.circlepath",
            title: "Trzymaj plecak gotowy",
            description: "Plecak powinien stać spakowany w łatwo dostępnym miejscu. Sprawdzaj i odświeżaj zawartość co kilka miesięcy — zwłaszcza daty ważności jedzenia i leków."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .mint)
                    }
                }

                FirstAidWarningBox(text: "Najlepszy moment na spakowanie plecaka ewakuacyjnego jest teraz — nie czekaj, aż będzie potrzebny za pięć minut.")
            }
            .padding()
        }
        .navigationTitle("Plecak ewakuacyjny")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "backpack.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.mint)
                .glassBadge(tint: .mint, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Dokumenty i plecak ewakuacyjny")
                .font(.title.weight(.bold))
            Text("Przygotowany zawczasu zestaw pozwala opuścić dom w kilka minut, jeśli zajdzie taka potrzeba.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        EvacuationBackpackView()
    }
}
