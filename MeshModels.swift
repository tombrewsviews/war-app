import MultipeerConnectivity

enum MessageRoute: String, Codable {
    case waiting
    case mesh
    case internet
}

struct MeshMessage: Identifiable, Codable {
    enum Kind: String, Codable {
        case chat
        case system
    }

    enum Status: String, Codable {
        case sent
        case queued
    }

    let id: UUID
    let senderName: String
    let text: String
    let timestamp: Date
    let kind: Kind
    var status: Status
    var route: MessageRoute

    init(id: UUID = UUID(), senderName: String, text: String, timestamp: Date = .now, kind: Kind = .chat, status: Status = .sent, route: MessageRoute = .waiting) {
        self.id = id
        self.senderName = senderName
        self.text = text
        self.timestamp = timestamp
        self.kind = kind
        self.status = status
        self.route = route
    }
}

struct MeshPeer: Identifiable {
    let peerID: MCPeerID
    var isConnected: Bool

    var id: MCPeerID { peerID }
    var displayName: String { peerID.displayName }
}

/// A person you've exchanged a persistent MESH code with (e.g. family) — independent of any single
/// session, since `MCPeerID`/display names are ephemeral and regenerated each time the mesh restarts.
struct MeshContact: Identifiable, Codable, Equatable {
    let id: UUID
    var nickname: String
    let code: String

    init(id: UUID = UUID(), nickname: String, code: String) {
        self.id = id
        self.nickname = nickname
        self.code = code
    }
}

struct MeshDirectMessage: Identifiable, Codable {
    enum Status: String, Codable {
        case sent
        case queued
    }

    let id: UUID
    let senderCode: String
    let senderName: String
    let recipientCode: String
    let text: String
    let timestamp: Date
    var status: Status
    var route: MessageRoute

    init(
        id: UUID = UUID(),
        senderCode: String,
        senderName: String,
        recipientCode: String,
        text: String,
        timestamp: Date = .now,
        status: Status = .sent,
        route: MessageRoute = .waiting
    ) {
        self.id = id
        self.senderCode = senderCode
        self.senderName = senderName
        self.recipientCode = recipientCode
        self.text = text
        self.timestamp = timestamp
        self.status = status
        self.route = route
    }
}
