import CoreLocation

enum BridgeStatus {
    case intact
    case destroyed
}

struct Bridge: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    var status: BridgeStatus
}

struct RiverCrossingPoint: Identifiable {
    let id = UUID()
    let name: String
    let coordinate: CLLocationCoordinate2D
    let approximateWidthMeters: Int
}

/// Placeholder for hazard pins that will later be pushed onto the map from the command-console
/// backend. Seeded locally with mock data for now so the map already knows how to render them.
struct MapHazard: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let coordinate: CLLocationCoordinate2D
    let severity: AlertSeverity
    let reportedAt: Date
}

enum CrossingRecommendation {
    case bridge(Bridge, distanceMeters: Double)
    case crossingPoint(RiverCrossingPoint, distanceMeters: Double)

    var title: String {
        switch self {
        case .bridge(let bridge, _): return "Najbliższy działający most: \(bridge.name)"
        case .crossingPoint(let point, _): return "Najwęższe miejsce koryta: \(point.name)"
        }
    }

    var subtitle: String {
        switch self {
        case .bridge(_, let distance): return "\(Int(distance)) m od zniszczonego mostu"
        case .crossingPoint(let point, let distance): return "ok. \(point.approximateWidthMeters) m szerokości koryta, \(Int(distance)) m od zniszczonego mostu"
        }
    }

    var coordinate: CLLocationCoordinate2D {
        switch self {
        case .bridge(let bridge, _): return bridge.coordinate
        case .crossingPoint(let point, _): return point.coordinate
        }
    }
}

/// Local mock of what will eventually be fed by the crisis-staff console: bridge status, known
/// river-crossing points, and hazard pins. `recommendation(for:)` implements the "which way around
/// a destroyed bridge" logic — the nearest intact bridge, or the nearest narrow crossing point,
/// whichever is closer.
@MainActor
@Observable
final class RiverCrossingStore {
    private(set) var bridges: [Bridge]
    private(set) var crossingPoints: [RiverCrossingPoint]
    private(set) var hazards: [MapHazard]

    init() {
        bridges = [
            Bridge(name: "Most Główny", coordinate: CLLocationCoordinate2D(latitude: 52.2297, longitude: 21.0122), status: .destroyed),
            Bridge(name: "Most Łazienkowski", coordinate: CLLocationCoordinate2D(latitude: 52.2205, longitude: 21.0350), status: .intact),
            Bridge(name: "Most Siekierkowski", coordinate: CLLocationCoordinate2D(latitude: 52.1900, longitude: 21.0500), status: .intact)
        ]

        crossingPoints = [
            RiverCrossingPoint(
                name: "Zakole przy Wale Miedzeszyńskim",
                coordinate: CLLocationCoordinate2D(latitude: 52.2350, longitude: 21.0600),
                approximateWidthMeters: 90
            ),
            RiverCrossingPoint(
                name: "Ławica przy Porcie Czerniakowskim",
                coordinate: CLLocationCoordinate2D(latitude: 52.2100, longitude: 21.0400),
                approximateWidthMeters: 70
            )
        ]

        hazards = [
            MapHazard(
                title: "Zablokowana droga",
                description: "Gruz po ostrzale blokuje przejazd. Objedź przez ul. Puławską.",
                coordinate: CLLocationCoordinate2D(latitude: 52.2260, longitude: 21.0200),
                severity: .important,
                reportedAt: .now.addingTimeInterval(-3600)
            )
        ]
    }

    func toggleBridgeStatus(_ bridge: Bridge) {
        guard let index = bridges.firstIndex(where: { $0.id == bridge.id }) else { return }
        bridges[index].status = bridges[index].status == .intact ? .destroyed : .intact
    }

    func recommendation(for bridge: Bridge) -> CrossingRecommendation? {
        guard bridge.status == .destroyed else { return nil }
        let origin = CLLocation(latitude: bridge.coordinate.latitude, longitude: bridge.coordinate.longitude)

        let bridgeCandidates: [(CrossingRecommendation, Double)] = bridges
            .filter { $0.id != bridge.id && $0.status == .intact }
            .map { candidate in
                let distance = origin.distance(from: CLLocation(latitude: candidate.coordinate.latitude, longitude: candidate.coordinate.longitude))
                return (.bridge(candidate, distanceMeters: distance), distance)
            }

        let pointCandidates: [(CrossingRecommendation, Double)] = crossingPoints.map { point in
            let distance = origin.distance(from: CLLocation(latitude: point.coordinate.latitude, longitude: point.coordinate.longitude))
            return (.crossingPoint(point, distanceMeters: distance), distance)
        }

        return (bridgeCandidates + pointCandidates).min { $0.1 < $1.1 }?.0
    }
}
