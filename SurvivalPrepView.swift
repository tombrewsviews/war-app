import SwiftUI

struct SurvivalPrepView: View {
    @Namespace private var namespace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                sections
            }
            .padding()
        }
        .navigationTitle("Przetrwanie")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Przetrwanie")
                .font(.largeTitle.weight(.bold))
            Text("Wiedza przygotowawcza na wypadek długotrwałego kryzysu — zanim będzie potrzebna.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sections: some View {
        VStack(spacing: 14) {
            prepLink("charging", destination: EmergencyChargingView()) {
                PrepMenuRow(
                    title: "Awaryjne ładowanie",
                    subtitle: "Jak naładować telefon bez prądu z sieci",
                    icon: "bolt.fill",
                    color: .yellow
                )
            }

            prepLink("wound", destination: WoundInfectionView()) {
                PrepMenuRow(
                    title: "Rany i infekcje",
                    subtitle: "Higiena ran i dlaczego domowe antybiotyki to zły pomysł",
                    icon: "bandage.fill",
                    color: .red
                )
            }

            prepLink("field", destination: FieldSurvivalView()) {
                PrepMenuRow(
                    title: "Przetrwanie w terenie",
                    subtitle: "Schronienie, ukrywanie się, poruszanie się bezpiecznie",
                    icon: "tree.fill",
                    color: .green
                )
            }

            prepLink("backpack", destination: EvacuationBackpackView()) {
                PrepMenuRow(
                    title: "Dokumenty i plecak ewakuacyjny",
                    subtitle: "Co spakować i przygotować zawczasu",
                    icon: "backpack.fill",
                    color: .mint
                )
            }
        }
    }

    private func prepLink(_ id: String, destination: some View, @ViewBuilder label: () -> some View) -> some View {
        NavigationLink {
            destination
                .navigationTransition(.zoom(sourceID: id, in: namespace))
        } label: {
            label()
                .matchedTransitionSource(id: id, in: namespace)
        }
        .buttonStyle(.tilePress)
    }
}

struct PrepMenuRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 64)
        .glassCard(tint: color, cornerRadius: 16, interactive: true)
        .foregroundStyle(.primary)
    }
}

#Preview {
    NavigationStack {
        SurvivalPrepView()
    }
}
