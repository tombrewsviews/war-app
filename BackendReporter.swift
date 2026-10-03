import CoreLocation
import Foundation

struct DeviceStatusUpdateRequest: Codable {
    var displayName: String
    var latitude: Double?
    var longitude: Double?
    var meshPeerCount: Int
}

/// Best-effort presence reporting to the crisis-staff console backend. MultipeerConnectivity is
/// local-only, so the console can't see live mesh topology directly — instead, whenever a phone
/// happens to have internet, it tells the server its own status (location, current mesh peer
/// count). The console then shows "last seen" rather than a truly live connection.
///
/// `baseURL` is hardcoded to localhost for this development phase (works from the iOS Simulator,
/// which shares the host Mac's network). A real deployment needs a reachable server address here —
/// not something this app can discover on its own yet.
@MainActor
@Observable
final class BackendReporter {
    private(set) var lastReportedAt: Date?

    private let baseURL: URL
    private let locationProvider = OneShotLocationProvider()
    @ObservationIgnored private var task: Task<Void, Never>?

    init(baseURL: URL = URL(string: "http://localhost:8080")!) {
        self.baseURL = baseURL
    }

    func start(code: String, displayName: @escaping () -> String, peerCount: @escaping () -> Int) {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                locationProvider.request()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await report(code: code, displayName: displayName(), peerCount: peerCount())
                try? await Task.sleep(nanoseconds: 25_000_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    private func report(code: String, displayName: String, peerCount: Int) async {
        var request = URLRequest(url: baseURL.appendingPathComponent("devices/\(code)"))
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = DeviceStatusUpdateRequest(
            displayName: displayName,
            latitude: locationProvider.coordinate?.latitude,
            longitude: locationProvider.coordinate?.longitude,
            meshPeerCount: peerCount
        )
        guard let data = try? JSONEncoder().encode(body) else { return }
        request.httpBody = data

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                lastReportedAt = .now
            }
        } catch {
            // No connection is the normal case for this app — fail silently, retry next cycle.
        }
    }
}
