import SwiftUI

struct FractureView: View {
    @State private var sosReporter = MeshSOSReporter()

    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "hand.raised.fill",
            title: "Nie poruszaj urazowanej kończyny",
            description: "Nie próbuj nastawiać ani wyprostowywać podejrzewanego złamania. Pozwól poszkodowanemu samemu znaleźć najmniej bolesną pozycję i unieruchom ją w takim ułożeniu."
        ),
        FirstAidStep(
            icon: "eye.fill",
            title: "Oceń rodzaj złamania",
            description: "Sprawdź, czy kość przebija skórę (złamanie otwarte) czy skóra jest niezniszczona (złamanie zamknięte) — to zmienia dalsze postępowanie."
        ),
        FirstAidStep(
            icon: "bandage.fill",
            title: "Unieruchom w zastanej pozycji",
            description: "Użyj deski, sztywnego kartonu, złożonej gazety lub zwiniętego ubrania jako szyny. Unieruchom staw powyżej i poniżej urazu, obwiązując delikatnie, ale stabilnie."
        ),
        FirstAidStep(
            icon: "waveform.path.ecg",
            title: "Kontroluj krążenie poniżej urazu",
            description: "Co kilka minut sprawdzaj kolor, ciepłotę i czucie w palcach poniżej szyny. Jeśli zbielały, są zimne lub zdrętwiały — poluzuj opatrunek."
        ),
        FirstAidStep(
            icon: "exclamationmark.triangle.fill",
            title: "Złamanie otwarte",
            description: "Osłoń ranę czystym opatrunkiem wokół wystającej kości. NIE dociskaj i nie próbuj wprowadzić kości z powrotem pod skórę."
        ),
        FirstAidStep(
            icon: "phone.fill",
            title: "Wezwij pomoc",
            description: "Zadzwoń pod 112 zwłaszcza przy złamaniu otwartym, podejrzeniu urazu kręgosłupa, miednicy lub kości udowej, albo gdy kończyna poniżej urazu traci krążenie."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .orange)
                    }
                }

                FirstAidWarningBox(text: "NIE próbuj samodzielnie nastawiać złamanej kości — możesz pogłębić uraz i uszkodzić naczynia lub nerwy.")

                EmergencyCallButton()

                MeshSOSStatusCard(reporter: sosReporter)
            }
            .padding()
        }
        .navigationTitle("Złamanie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "bandage.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.orange)
                    .glassBadge(tint: .orange, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                CompactEmergencyCallButton()
                CompactMeshSOSButton(reporter: sosReporter)
            }

            Text("Złamanie")
                .font(.title.weight(.bold))
            Text("Unieruchomienie i ostrożność liczą się bardziej niż pośpiech — nie próbuj nastawiać kości samodzielnie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        FractureView()
    }
}
