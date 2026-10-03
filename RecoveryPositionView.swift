import SwiftUI

struct RecoveryPositionView: View {
    @State private var sosReporter = MeshSOSReporter()

    private let steps: [FirstAidStep] = [
        FirstAidStep(
            icon: "person.fill.questionmark",
            title: "Sprawdź reakcję i oddech",
            description: "Jeśli osoba nie reaguje, ale oddycha prawidłowo — ułóż ją w pozycji bocznej bezpiecznej. Jeśli oddech jest nieprawidłowy lub go nie ma, zamiast tego zacznij RKO."
        ),
        FirstAidStep(
            icon: "hand.raised.fill",
            title: "Ułóż bliższe ramię pod kątem prostym",
            description: "Uklęknij przy poszkodowanym. Wyprostuj ramię bliżej Ciebie i ułóż je pod kątem prostym do ciała, dłonią zwróconą do góry."
        ),
        FirstAidStep(
            icon: "hand.point.up.fill",
            title: "Dalszą rękę połóż pod policzek",
            description: "Przełóż dalszą rękę poszkodowanego na jego drugi policzek — wierzch dłoni powinien opierać się o policzek bliżej Ciebie."
        ),
        FirstAidStep(
            icon: "figure.walk",
            title: "Zegnij dalszą nogę w kolanie",
            description: "Chwyć dalszą nogę poniżej kolana i zegnij ją tak, by stopa oparła się płasko na ziemi."
        ),
        FirstAidStep(
            icon: "arrow.triangle.2.circlepath",
            title: "Obróć poszkodowanego na bok",
            description: "Ciągnąc za zgięte kolano, delikatnie przewróć poszkodowanego w swoją stronę, aż znajdzie się na boku."
        ),
        FirstAidStep(
            icon: "wind",
            title: "Odblokuj drogi oddechowe",
            description: "Odegnij głowę lekko do tyłu, aby udrożnić drogi oddechowe. Usta powinny być skierowane nieco w dół, by umożliwić odpływ wydzielin lub wymiocin."
        ),
        FirstAidStep(
            icon: "phone.fill",
            title: "Wezwij pomoc i monitoruj",
            description: "Zadzwoń pod 112. Regularnie sprawdzaj, czy poszkodowany wciąż oddycha prawidłowo, aż do przybycia pomocy."
        )
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                        FirstAidStepRow(index: index + 1, step: step, tint: .blue)
                    }
                }

                FirstAidWarningBox(text: "Jeśli poszkodowany NIE oddycha prawidłowo, natychmiast zacznij RKO — nie układaj go w pozycji bezpiecznej.")

                EmergencyCallButton()

                MeshSOSStatusCard(reporter: sosReporter)
            }
            .padding()
        }
        .navigationTitle("Pozycja boczna bezpieczna")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "figure.arms.open")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.blue)
                    .glassBadge(tint: .blue, size: 52, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                Spacer()

                CompactEmergencyCallButton()
                CompactMeshSOSButton(reporter: sosReporter)
            }

            Text("Pozycja boczna bezpieczna")
                .font(.title.weight(.bold))
            Text("Dla osoby nieprzytomnej, która oddycha prawidłowo — chroni drogi oddechowe do przyjazdu pomocy.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        RecoveryPositionView()
    }
}
