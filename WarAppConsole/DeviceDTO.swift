import Foundation

/// Mirrors the server's `DeviceDTO`. A device's last-reported presence, not a live connection —
/// see BackendReporter.swift in the iOS app for why (MultipeerConnectivity can't reach a remote
/// console directly).
struct DeviceDTO: Codable, Identifiable {
    var code: String
    var displayName: String
    var latitude: Double?
    var longitude: Double?
    var meshPeerCount: Int
    var lastSeenAt: Date

    var id: String { code }

    var isRecentlySeen: Bool {
        Date.now.timeIntervalSince(lastSeenAt) < 2 * 60
    }
}
