import CoreLocation

enum SafetyPointCategory {
    case shelter
    case helpPoint
}

struct SafetyPoint: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let coordinate: CLLocationCoordinate2D
    let category: SafetyPointCategory
}

/// Raw shape of an entry in the bundled `WarsawShelters.json`, sourced from the official national
/// "Punkty schronienia w Polsce" register (dane.gov.pl/pl/dataset/28058, CC BY 4.0, published by
/// PSP/RCB and mirrored at gdziesieukryc.pl). Filtered to Gmina == Warszawa at build time.
private struct RawShelterEntry: Decodable {
    let id: String
    let address: String
    let latitude: Double
    let longitude: Double
    let availability: String
}

/// Seeds the shelter list from two real, publicly sourced layers:
/// 1. A handful of well-known Warsaw metro stations (confirmed by PSP/RCB reporting as part of the
///    doraźne schronienie network) — easy to recognize, always staffed during operating hours.
/// 2. The bundled `WarsawShelters.json` — 288 official "Obiekt ochrony ludności" points for Warszawa,
///    pulled from the national government dataset (see `RawShelterEntry` above). That's the real
///    register, not a mock; it's a subset (Warszawa only) of the ~86 000-point national file, which
///    updates independently at gdziesieukryc.pl — this snapshot won't stay perfectly in sync with it.
///
/// `helpPoints` is intentionally empty: aid points and any additional shelter locations will be
/// pushed in later from the crisis-staff backend/console, same as `MapHazard`.
@MainActor
@Observable
final class SafetyPointStore {
    private(set) var shelters: [SafetyPoint]
    private(set) var helpPoints: [SafetyPoint] = []

    init() {
        let metroStations = [
            SafetyPoint(
                name: "Metro Centrum",
                subtitle: "Stacja metra — punkt doraźnego schronienia",
                coordinate: CLLocationCoordinate2D(latitude: 52.2298, longitude: 21.0059),
                category: .shelter
            ),
            SafetyPoint(
                name: "Metro Świętokrzyska",
                subtitle: "Stacja metra — punkt doraźnego schronienia",
                coordinate: CLLocationCoordinate2D(latitude: 52.2359, longitude: 21.0122),
                category: .shelter
            ),
            SafetyPoint(
                name: "Metro Ratusz Arsenał",
                subtitle: "Stacja metra — punkt doraźnego schronienia",
                coordinate: CLLocationCoordinate2D(latitude: 52.2469, longitude: 21.0034),
                category: .shelter
            ),
            SafetyPoint(
                name: "Metro Politechnika",
                subtitle: "Stacja metra — punkt doraźnego schronienia",
                coordinate: CLLocationCoordinate2D(latitude: 52.2210, longitude: 21.0089),
                category: .shelter
            ),
            SafetyPoint(
                name: "Metro Dworzec Wileński",
                subtitle: "Stacja metra — punkt doraźnego schronienia (Praga)",
                coordinate: CLLocationCoordinate2D(latitude: 52.2564, longitude: 21.0378),
                category: .shelter
            )
        ]

        shelters = metroStations + Self.loadOfficialShelters()
    }

    private static func loadOfficialShelters() -> [SafetyPoint] {
        guard let url = Bundle.main.url(forResource: "WarsawShelters", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([RawShelterEntry].self, from: data)
        else { return [] }

        return entries.map { entry in
            SafetyPoint(
                name: entry.address,
                subtitle: "Obiekt ochrony ludności — dostępność: \(entry.availability.lowercased())",
                coordinate: CLLocationCoordinate2D(latitude: entry.latitude, longitude: entry.longitude),
                category: .shelter
            )
        }
    }
}

/// One-shot current-location lookup, used only to sort the list by distance and show "X km" —
/// navigation itself doesn't need this, since Apple Maps resolves the user's position on its own.
@MainActor
@Observable
final class OneShotLocationProvider: NSObject {
    private(set) var coordinate: CLLocationCoordinate2D?

    @ObservationIgnored private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
    }

    func request() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }
    }
}

extension OneShotLocationProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.coordinate = locations.last?.coordinate
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}
