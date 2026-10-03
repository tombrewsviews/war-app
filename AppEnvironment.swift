import CoreLocation
import Network
import SwiftUI

/// App-wide services that need to keep running regardless of which screen is on top — mesh
/// networking, backend sync, and location/connectivity status — so the home screen's status bar
/// always reflects the real, current state instead of a snapshot from whenever that screen was
/// last open. Created once, at app launch, and injected into the view hierarchy via `.environment`.
@MainActor
@Observable
final class AppEnvironment {
    let meshController = MeshController()
    let backendReporter = BackendReporter()
    let alertStore = AlertStore()
    let locationStatus = LocationStatusProvider()
    let connectivityMonitor = ConnectivityMonitor()
    let commandCenterStatus = CommandCenterStatus()

    init() {
        meshController.start()
        backendReporter.start(
            code: meshController.myContactCode,
            displayName: { [meshController] in meshController.displayName },
            peerCount: { [meshController] in meshController.peers.filter(\.isConnected).count }
        )
        locationStatus.start()
        connectivityMonitor.start()
        commandCenterStatus.start()
    }
}

/// Reachability check against the public "Centrum Dowodzenia" status page (a static GitHub Pages
/// site for now — repo `warapp-backend`) — a real internet-hosted target the app can verify
/// end-to-end connectivity against today, ahead of a full dynamic backend going live there.
@MainActor
@Observable
final class CommandCenterStatus {
    enum State: Equatable {
        case unknown
        case reachable
        case unreachable
    }

    private(set) var state: State = .unknown
    private(set) var lastCheckedAt: Date?

    private let statusURL: URL
    @ObservationIgnored private var task: Task<Void, Never>?

    init(statusURL: URL = URL(string: "https://aczykoty.github.io/warapp-backend/status.json")!) {
        self.statusURL = statusURL
    }

    func start() {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                await check()
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func check() async {
        var request = URLRequest(url: statusURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        defer { lastCheckedAt = .now }
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  json["status"] as? String == "online"
            else {
                state = .unreachable
                return
            }
            state = .reachable
        } catch {
            state = .unreachable
        }
    }
}

/// Tracks whether we currently have a *recent* location fix — not just "permission granted" — so
/// the home screen's GPS dot can honestly show red (no usable fix yet) vs green (locked on).
@MainActor
@Observable
final class LocationStatusProvider: NSObject {
    private(set) var hasRecentFix = false

    @ObservationIgnored private let manager = CLLocationManager()
    @ObservationIgnored private var lastFixAt: Date?
    @ObservationIgnored private var staleCheckTask: Task<Void, Never>?

    private let staleAfter: TimeInterval = 60

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    func start() {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        default:
            break
        }

        guard staleCheckTask == nil else { return }
        staleCheckTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                refreshFixState()
            }
        }
    }

    private func refreshFixState() {
        guard let lastFixAt else {
            hasRecentFix = false
            return
        }
        hasRecentFix = Date.now.timeIntervalSince(lastFixAt) < staleAfter
    }
}

extension LocationStatusProvider: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        Task { @MainActor in
            self.lastFixAt = .now
            self.hasRecentFix = true
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            default:
                self.hasRecentFix = false
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {}
}

/// App-wide "do we currently have any internet path at all" — distinct from whether we've actually
/// managed to sync with our backend (`BackendReporter.lastReportedAt`). Being online but not yet
/// synced, and having no connection at all, are different diagnostic states worth telling apart.
@MainActor
@Observable
final class ConnectivityMonitor {
    private(set) var isOnline = true

    @ObservationIgnored private let monitor = NWPathMonitor()

    func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "ConnectivityMonitor"))
    }
}
