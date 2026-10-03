import SwiftUI

struct FieldSurvivalView: View {
    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "thermometer.snowflake",
            title: "Priorytet: schronienie przed pogodą",
            description: "Człowiek może przetrwać tygodnie bez jedzenia, ale tylko godziny bez ochrony przed zimnem, upałem czy deszczem. Osłoń się, zanim zaczniesz szukać jedzenia."
        ),
        FirstAidStep(
            icon: "tree.fill",
            title: "Proste schronienie",
            description: "Wykorzystaj naturalne osłony: zagłębienia terenu, gęste zarośla, powalone drzewa. Izolacja od zimnej ziemi (gałęzie, liście pod spodem) jest ważniejsza niż osłona od góry — przez kontakt z podłożem tracisz najwięcej ciepła."
        ),
        FirstAidStep(
            icon: "eye.slash.fill",
            title: "Jak się nie rzucać w oczy",
            description: "Unikaj sylwetki na tle nieba (grzbiety wzgórz, otwarte pola). Poruszaj się wzdłuż linii cienia i roślinności. Ogranicz ruch o świcie i zmierzchu, gdy widoczność dla obserwatora jest najlepsza."
        ),
        FirstAidStep(
            icon: "speaker.slash.fill",
            title: "Cisza i dyscyplina świetlna",
            description: "Wycisz telefon całkowicie. Osłoń każde źródło światła — nawet ekran telefonu jest widoczny z daleka po zmroku. Mów szeptem, ogranicz zbędne dźwięki."
        ),
        FirstAidStep(
            icon: "drop.fill",
            title: "Woda — priorytet zaraz po schronieniu",
            description: "Szukaj płynącej wody (rzeka, strumień) zamiast stojącej. Zawsze oczyszczaj przed piciem: przegotowanie przez minutę, tabletki odkażające albo filtr turystyczny."
        ),
        FirstAidStep(
            icon: "location.north.line.fill",
            title: "Orientacja bez GPS",
            description: "Pozycja słońca (wschód/zachód) i gwiazdy (Gwiazda Polarna w nocy) są dużo pewniejsze niż mit o mchu rosnącym „zawsze po północnej stronie” drzew — to nieprawda, mech rośnie tam, gdzie jest wilgotno."
        ),
        FirstAidStep(
            icon: "figure.walk",
            title: "Jeśli musisz unikać kontaktu",
            description: "Zmieniaj kierunek marszu, unikaj utartych szlaków i dróg. Ustal wcześniej z grupą punkt zbiórki na wypadek rozdzielenia. Priorytetem jest uniknięcie zagrożenia, nie konfrontacja."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .green)
                    }
                }

                FirstAidWarningBox(text: "Przeżycie, nie heroizm — jeśli możesz uniknąć niebezpieczeństwa bez konfrontacji, zawsze wybieraj tę drogę.")
            }
            .padding()
        }
        .navigationTitle("Przetrwanie w terenie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "tree.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.green)
                .glassBadge(tint: .green, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("Przetrwanie w terenie")
                .font(.title.weight(.bold))
            Text("Podstawy bezpiecznego przetrwania na otwartym terenie: schronienie, dyskrecja i orientacja.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        FieldSurvivalView()
    }
}
