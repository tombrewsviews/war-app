import SwiftUI

struct FirstAidView: View {
    @Namespace private var namespace

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                sections
            }
            .padding()
        }
        .navigationTitle("Pierwsza pomoc")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pierwsza pomoc")
                .font(.largeTitle.weight(.bold))
            Text("Wybierz sytuację, z którą masz do czynienia. Instrukcje krok po kroku pomogą Ci działać szybko i bezpiecznie.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var sections: some View {
        VStack(spacing: 16) {
            menuLink(
                id: "resuscitation",
                destination: ResuscitationView(),
                title: "Resuscytacja",
                subtitle: "RKO – uciski klatki piersiowej i oddechy",
                icon: "heart.fill",
                color: .pink
            )

            menuLink(
                id: "bleeding",
                destination: BleedingControlView(),
                title: "Krwawienie",
                subtitle: "Tamowanie krwotoków, opaska zaciskowa",
                icon: "bandage.fill",
                color: .red
            )

            menuLink(
                id: "fracture",
                destination: FractureView(),
                title: "Złamanie",
                subtitle: "Unieruchomienie i kontrola krążenia",
                icon: "figure.fall",
                color: .orange
            )

            menuLink(
                id: "recovery",
                destination: RecoveryPositionView(),
                title: "Pozycja boczna bezpieczna",
                subtitle: "Dla osoby nieprzytomnej, która oddycha",
                icon: "figure.arms.open",
                color: .blue
            )
        }
    }

    private func menuLink(id: String, destination: some View, title: String, subtitle: String, icon: String, color: Color) -> some View {
        NavigationLink {
            destination
                .navigationTransition(.zoom(sourceID: id, in: namespace))
        } label: {
            FirstAidMenuRow(title: title, subtitle: subtitle, icon: icon, color: color)
                .matchedTransitionSource(id: id, in: namespace)
        }
        .buttonStyle(.tilePress)
    }
}

private struct FirstAidMenuRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(color)
                .glassBadge(tint: color, size: 60, in: RoundedRectangle(cornerRadius: 18, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.weight(.bold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.secondary)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 108)
        .glassCard(tint: color, cornerRadius: 22, interactive: true)
        .foregroundStyle(.primary)
    }
}

#Preview {
    NavigationStack {
        FirstAidView()
    }
}
