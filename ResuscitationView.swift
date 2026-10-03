import SwiftUI

struct ResuscitationView: View {
    @State private var sosReporter = MeshSOSReporter()

    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "person.fill.questionmark",
            title: "Sprawdź bezpieczeństwo i reakcję",
            description: "Upewnij się, że miejsce jest bezpieczne. Potrząśnij poszkodowanego za ramiona i zapytaj głośno: „Czy wszystko w porządku?”."
        ),
        FirstAidStep(
            icon: "phone.fill",
            title: "Wezwij pomoc",
            description: "Brak reakcji? Krzyknij o pomoc i zadzwoń pod 112 — włącz głośnomówiący, by działać jednocześnie."
        ),
        FirstAidStep(
            icon: "wind",
            title: "Udrożnij drogi oddechowe",
            description: "Odegnij głowę poszkodowanego do tyłu i unieś żuchwę (rękoczyn czoło–żuchwa)."
        ),
        FirstAidStep(
            icon: "waveform",
            title: "Sprawdź oddech (max 10 s)",
            description: "Patrz, słuchaj, czuj. Nieregularne, pojedyncze „łapanie” powietrza (gasping) to NIE prawidłowy oddech."
        ),
        FirstAidStep(
            icon: "hand.point.down.fill",
            title: "Zacznij uciski klatki piersiowej",
            description: "Środek klatki piersiowej, ręce wyprostowane, głębokość 5–6 cm, tempo 100–120/min. Pozwól klatce w pełni unieść się między uciśnięciami. Wskazówka: tempo odpowiada rytmowi piosenki „Stayin' Alive”."
        ),
        FirstAidStep(
            icon: "arrow.triangle.2.circlepath",
            title: "30 uciśnięć, 2 oddechy",
            description: "Jeśli jesteś przeszkolony i możesz — po 30 uciśnięciach wykonaj 2 oddechy ratownicze. Jeśli nie, kontynuuj same uciski bez przerwy."
        ),
        FirstAidStep(
            icon: "bolt.fill",
            title: "Użyj AED, jeśli dostępny",
            description: "Włącz defibrylator (AED) jak najszybciej i postępuj zgodnie z instrukcjami głosowymi. Nie przerywaj uciśnięć dłużej niż na czas analizy rytmu."
        ),
        FirstAidStep(
            icon: "clock.fill",
            title: "Kontynuuj do przybycia pomocy",
            description: "Nie przerywaj RKO, dopóki poszkodowany nie zacznie oddychać prawidłowo, nie przyjedzie pomoc lub nie będziesz całkowicie wyczerpany."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                CPRMetronomeCard()

                handPlacementDiagram

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .pink)
                    }
                }

                VStack(spacing: 10) {
                    FirstAidWarningBox(text: "NIE przerywaj uciśnięć na dłużej niż 10 sekund, chyba że AED analizuje rytm.")
                    FirstAidWarningBox(text: "Kobiety w widocznej ciąży i dzieci wymagają innej techniki — jeśli to możliwe, poproś dyspozytora 112 o wskazówki.")
                }

                MeshSOSStatusCard(reporter: sosReporter)
            }
            .padding()
        }
        .navigationTitle("Resuscytacja")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var handPlacementDiagram: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Gdzie i jak ułożyć dłonie")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            Image("CPRHandPlacement")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 150)
                .padding(6)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(6)
                .glassCard(tint: .pink, cornerRadius: 16)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.pink)
                    .glassBadge(tint: .pink, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                CompactEmergencyCallButton()
                CompactMeshSOSButton(reporter: sosReporter)
            }

            Text("Resuscytacja krążeniowo-oddechowa")
                .font(.title.weight(.bold))
            Text("Postępuj krok po kroku. RKO rozpoczęte szybko znacząco zwiększa szansę na przeżycie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        ResuscitationView()
    }
}
