import CoreLocation
import MapKit
import Network
import UIKit

/// Keeps a raster snapshot of the ~10 km radius around the user cached to disk, so the crisis map
/// stays usable offline. MapKit has no official "download this region for offline use" API — this
/// is the practical equivalent: whenever the user moves into a new ~10 km grid cell and a network
/// connection is available, `MKMapSnapshotter` renders and saves that cell as a PNG. When the
/// connection drops, the view falls back to the most recent cached image near the user's location.
@MainActor
@Observable
final class OfflineMapCache: NSObject {
    struct CachedRegion: Identifiable {
        let id: String
        let coordinate: CLLocationCoordinate2D
        let savedAt: Date
        let fileURL: URL
    }

    private(set) var cachedRegions: [CachedRegion] = []
    private(set) var isOffline = false
    private(set) var currentCoordinate: CLLocationCoordinate2D?
    private(set) var isDownloading = false
    private(set) var lastDownloadError: String?
    private(set) var authorizationStatus: CLAuthorizationStatus

    private let radiusMeters: CLLocationDistance = 10_000
    /// ~10 km per grid cell at moderate latitudes — good enough for a cache bucket, not for navigation.
    private let gridSizeDegrees = 0.09

    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private let pathMonitor = NWPathMonitor()
    @ObservationIgnored private var lastCheckedGridKey: String?
    @ObservationIgnored private var lastAttemptAt: Date?

    private var cacheDirectory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("OfflineMaps", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override init() {
        authorizationStatus = CLLocationManager().authorizationStatus
        super.init()
        loadCachedRegionsFromDisk()

        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyKilometer
        locationManager.distanceFilter = 2_000

        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                guard let self else { return }
                self.isOffline = path.status != .satisfied
            }
        }
        pathMonitor.start(queue: DispatchQueue(label: "OfflineMapCache.pathMonitor"))
    }

    func start() {
        authorizationStatus = locationManager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
        default:
            break
        }
    }

    func stop() {
        locationManager.stopUpdatingLocation()
    }

    func cachedImage(near coordinate: CLLocationCoordinate2D) -> UIImage? {
        guard let closest = cachedRegions.min(by: {
            distance($0.coordinate, coordinate) < distance($1.coordinate, coordinate)
        }) else { return nil }
        return UIImage(contentsOfFile: closest.fileURL.path)
    }

    private func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    private func gridKey(for coordinate: CLLocationCoordinate2D) -> String {
        let latBucket = Int((coordinate.latitude / gridSizeDegrees).rounded())
        let lonBucket = Int((coordinate.longitude / gridSizeDegrees).rounded())
        return "\(latBucket)_\(lonBucket)"
    }

    private func ensureCurrentRegionCached(around coordinate: CLLocationCoordinate2D) {
        let key = gridKey(for: coordinate)

        if let existing = cachedRegions.first(where: { $0.id == key }),
           Date.now.timeIntervalSince(existing.savedAt) < 24 * 60 * 60 {
            return
        }

        // Retry failed/never-attempted cells, but not on every single location tick —
        // a transient snapshotter/network failure shouldn't permanently disable this cell.
        guard !isDownloading else { return }
        if key == lastCheckedGridKey, let lastAttempt = lastAttemptAt, Date.now.timeIntervalSince(lastAttempt) < 15 {
            return
        }
        lastCheckedGridKey = key
        lastAttemptAt = .now

        guard !isOffline else { return }
        downloadSnapshot(for: coordinate, key: key)
    }

    private func downloadSnapshot(for coordinate: CLLocationCoordinate2D, key: String) {
        isDownloading = true
        lastDownloadError = nil

        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: coordinate, latitudinalMeters: radiusMeters * 2, longitudinalMeters: radiusMeters * 2)
        options.size = CGSize(width: 1024, height: 1024)
        options.mapType = .standard

        let snapshotter = MKMapSnapshotter(options: options)
        snapshotter.start { [weak self] snapshot, error in
            Task { @MainActor in
                guard let self else { return }
                self.isDownloading = false

                guard let snapshot, error == nil else {
                    self.lastDownloadError = "Nie udało się pobrać mapy offline dla tego obszaru."
                    return
                }

                let fileURL = self.cacheDirectory.appendingPathComponent("\(key).png")
                guard let data = snapshot.image.pngData() else { return }
                try? data.write(to: fileURL, options: .atomic)

                let region = CachedRegion(id: key, coordinate: coordinate, savedAt: .now, fileURL: fileURL)
                self.cachedRegions.removeAll { $0.id == key }
                self.cachedRegions.append(region)
            }
        }
    }

    private func loadCachedRegionsFromDisk() {
        let fileManager = FileManager.default
        guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else { return }

        cachedRegions = files.compactMap { url -> CachedRegion? in
            guard url.pathExtension == "png" else { return nil }
            let key = url.deletingPathExtension().lastPathComponent
            let parts = key.split(separator: "_").compactMap { Double($0) }
            guard parts.count == 2 else { return nil }

            let coordinate = CLLocationCoordinate2D(latitude: parts[0] * gridSizeDegrees, longitude: parts[1] * gridSizeDegrees)
            let modifiedDate = (try? fileManager.attributesOfItem(atPath: url.path)[.modificationDate] as? Date) ?? Date.now
            return CachedRegion(id: key, coordinate: coordinate, savedAt: modifiedDate, fileURL: url)
        }
    }
}

extension OfflineMapCache: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let coordinate = locations.last?.coordinate else { return }
        Task { @MainActor in
            self.currentCoordinate = coordinate
            self.ensureCurrentRegionCached(around: coordinate)
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                manager.startUpdatingLocation()
            default:
                break
            }
        }
    }
}
