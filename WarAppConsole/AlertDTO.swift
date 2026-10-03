import Foundation

/// Mirrors the server's `AlertDTO` (WarAppServer/Sources/WarAppServer/Models/AlertDTO.swift), which
/// in turn mirrors `AlertItem` in the iOS app (WarApp/AlertModels.swift). Three copies of one small
/// shape for now — worth collapsing into a shared package once there's a second resource type.
struct AlertDTO: Codable, Identifiable {
    var id: UUID
    var title: String
    var message: String
    var severity: String
    var lifecycle: String
    var location: String?
    var createdAt: Date
    var isUserSubmitted: Bool
}

struct AlertCreateRequest: Codable {
    var title: String
    var message: String
    var severity: String
    var location: String?
}

struct AlertLifecycleUpdateRequest: Codable {
    var lifecycle: String
}
