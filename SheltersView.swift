import SwiftUI
import MapKit
import CoreLocation

struct SheltersView: View {
    @State private var store = SafetyPointStore()
    @State private var locationProvider = OneShotLocationProvider()
    @State private var shelterDisplayLimit = 20

    private static let pageSize = 20

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                officialSourceBanner

                section(
                    title: "Schrony (\(sortedShelters.count))",
                    icon: "building.2.fill",
                    color: .brown,
                    points: Array(sortedShelters.prefix(shelterDisplayLimit)),
                    emptyText: "Brak schronów na liście."
                )

                if shelterDisplayLimit < sortedShelters.count {
                    Button("Pokaż więcej (\(sortedShelters.count - shelterDisplayLimit) dalszych)") {
                        withAnimation(.snappy) {
                            shelterDisplayLimit = min(shelterDisplayLimit + Self.pageSize, sortedShelters.count)
                        }
                    }
                    .font(.footnote.weight(.semibold))
                    .transition(.opacity)
                }

                section(
                    title: "Punkty pomocy",
                    icon: "cross.fill",
                    color: .red,
                    points: store.helpPoints,
                    emptyText: "Punkty pomocy pojawią się tutaj automatycznie, gdy sztab kryzysowy zacznie je przesyłać z systemu."
                )
            }
            .padding()
        }
        .navigationTitle("Schrony i punkty pomocy")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { locationProvider.request() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Schrony i punkty pomocy")
                .font(.largeTitle.weight(.bold))
            Text("Wybierz punkt i nawiguj do niego. Najbliższe schrony są zawsze na górze listy. Dane pochodzą z oficjalnego rejestru PSP/RCB; punkty pomocy sztab będzie dodawał na bieżąco.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var officialSourceBanner: some View {
        Button {
            if let url = URL(string: "https://gdziesieukryc.pl") {
                UIApplication.shared.open(url)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "link.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Pełna, aktualna mapa schronów")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("gdziesieukryc.pl — oficjalne narzędzie Państwowej Straży Pożarnej")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .glassCard(tint: .blue, cornerRadius: 12)
        }
        .buttonStyle(.tilePress)
    }

    private var sortedShelters: [SafetyPoint] {
        guard let coordinate = locationProvider.coordinate else { return store.shelters }
        let origin = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return store.shelters.sorted {
            distance(from: origin, to: $0.coordinate) < distance(from: origin, to: $1.coordinate)
        }
    }

    private func distance(from origin: CLLocation, to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        origin.distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude))
    }

    private func distanceText(for point: SafetyPoint) -> String? {
        guard let coordinate = locationProvider.coordinate else { return nil }
        let meters = distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude), to: point.coordinate)
        return meters >= 1000 ? String(format: "%.1f km", meters / 1000) : "\(Int(meters)) m"
    }

    @ViewBuilder
    private func section(title: String, icon: String, color: Color, points: [SafetyPoint], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            if points.isEmpty {
                Text(emptyText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(points) { point in
                        SafetyPointRow(point: point, color: color, icon: icon, distanceText: distanceText(for: point))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
            }
        }
    }
}

struct SafetyPointRow: View {
    let point: SafetyPoint
    let color: Color
    let icon: String
    let distanceText: String?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .glassBadge(tint: color, size: 38, in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(point.name)
                    .font(.subheadline.weight(.semibold))
                Text(point.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let distanceText {
                    Text(distanceText)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(color)
                }
            }

            Spacer()

            Button {
                navigate(to: point)
            } label: {
                Label("Nawiguj", systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(color)
        }
        .padding(10)
        .glassCard(cornerRadius: 12)
    }

    private func navigate(to point: SafetyPoint) {
        let location = CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude)
        let mapItem = MKMapItem(location: location, address: nil)
        mapItem.name = point.name
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

#Preview {
    NavigationStack {
        SheltersView()
    }
}
