import MultipeerConnectivity

/// Drives the MESH channel using MultipeerConnectivity (Bluetooth + Wi-Fi peer-to-peer, no internet
/// or shared infrastructure required). Every device both advertises itself and browses for others,
/// so any two — or more — copies of the app in range mesh up automatically. Broadcast messages go to
/// all currently connected peers; multi-hop relaying beyond direct radio range isn't implemented yet,
/// since MultipeerConnectivity only gives us direct peer links, not a routed mesh.
///
/// Contacts are identified by a persistent, human-shareable code (independent of the ephemeral
/// `MCPeerID`/display name, which is regenerated whenever the mesh restarts). The code rides along
/// in the advertiser's `discoveryInfo`, so a peer's identity is known as soon as it's discovered —
/// before any session is even established — letting the UI show "w zasięgu" for known contacts.
@MainActor
@Observable
final class MeshController: NSObject {
    static let meshCharacterLimit = 240
    enum ConnectionState: Equatable {
        case idle
        case searching
        case connected(Int)
    }

    private(set) var state: ConnectionState = .idle
    private(set) var isRunning = false
    private(set) var peers: [MeshPeer] = []
    private(set) var messages: [MeshMessage] = []
    private(set) var directMessages: [MeshDirectMessage] = []
    private(set) var contacts: [MeshContact] = []
    private(set) var discoveredCodes: [MCPeerID: String] = [:]
    private(set) var displayName: String
    let myContactCode: String

    private(set) var readGeneralMessageIDs: Set<UUID> = []
    private(set) var readDirectMessageIDs: Set<UUID> = []

    private let serviceType = "warapp-mesh"
    private static let displayNameKey = "meshDisplayName"
    private static let contactCodeKey = "meshContactCode"
    private static let contactsKey = "meshContacts"

    private struct Envelope: Codable {
        enum Kind: String, Codable { case broadcast, direct }
        let kind: Kind
        let payload: Data
    }

    @ObservationIgnored private var myPeerID: MCPeerID
    @ObservationIgnored private var session: MCSession?
    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?

    override init() {
        let savedName = UserDefaults.standard.string(forKey: Self.displayNameKey)
        let name = savedName ?? Self.randomCallsign()
        displayName = name
        myPeerID = MCPeerID(displayName: name)

        if let savedCode = UserDefaults.standard.string(forKey: Self.contactCodeKey) {
            myContactCode = savedCode
        } else {
            let generated = Self.generateContactCode()
            UserDefaults.standard.set(generated, forKey: Self.contactCodeKey)
            myContactCode = generated
        }

        if let data = UserDefaults.standard.data(forKey: Self.contactsKey),
           let decoded = try? JSONDecoder().decode([MeshContact].self, from: data) {
            contacts = decoded
        }

        super.init()
    }

    func start() {
        guard !isRunning else { return }
        isRunning = true
        state = .searching

        let session = MCSession(peer: myPeerID, securityIdentity: nil, encryptionPreference: .required)
        session.delegate = self
        self.session = session

        let advertiser = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: ["code": myContactCode], serviceType: serviceType)
        advertiser.delegate = self
        advertiser.startAdvertisingPeer()
        self.advertiser = advertiser

        let browser = MCNearbyServiceBrowser(peer: myPeerID, serviceType: serviceType)
        browser.delegate = self
        browser.startBrowsingForPeers()
        self.browser = browser

        addSystemMessage("Rozpoczęto wyszukiwanie urządzeń w sieci MESH jako „\(displayName)”…")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session?.disconnect()
        advertiser = nil
        browser = nil
        session = nil
        peers = []
        discoveredCodes = [:]
        state = .idle
        addSystemMessage("Sieć MESH zatrzymana.")
    }

    // MARK: Broadcast (general chat)

    func send(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let limitedText = String(trimmed.prefix(Self.meshCharacterLimit))

        var message = MeshMessage(senderName: displayName, text: limitedText, status: .queued, route: .waiting)
        if broadcast(message) {
            message.status = .sent
            message.route = .mesh
        }
        messages.append(message)
    }

    @discardableResult
    private func broadcast(_ message: MeshMessage) -> Bool {
        var outgoingMessage = message
        outgoingMessage.status = .sent
        outgoingMessage.route = .mesh
        guard let session, !session.connectedPeers.isEmpty,
              let payload = try? JSONEncoder().encode(outgoingMessage),
              let data = try? JSONEncoder().encode(Envelope(kind: .broadcast, payload: payload))
        else { return false }
        do {
            try session.send(data, toPeers: session.connectedPeers, with: .reliable)
            return true
        } catch {
            return false
        }
    }

    /// Outbox flush for the general chat — retries any of *our own* broadcast messages still
    /// marked `.queued` (sent while no peers were in range) whenever a peer connects, mirroring
    /// `flushQueuedDirectMessages` for direct messages.
    private func flushQueuedBroadcastMessages() {
        for index in messages.indices {
            guard messages[index].status == .queued,
                  messages[index].kind == .chat,
                  messages[index].senderName == displayName
            else { continue }

            if broadcast(messages[index]) {
                messages[index].status = .sent
                messages[index].route = .mesh
            }
        }
    }

    // MARK: Contacts & direct messages

    func addContact(code: String, nickname: String) {
        let trimmedCode = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedName = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCode.isEmpty, !trimmedName.isEmpty, trimmedCode != myContactCode else { return }
        guard !contacts.contains(where: { $0.code == trimmedCode }) else { return }

        contacts.append(MeshContact(nickname: trimmedName, code: trimmedCode))
        persistContacts()
    }

    func removeContact(_ contact: MeshContact) {
        contacts.removeAll { $0.id == contact.id }
        persistContacts()
    }

    func isContactInMesh(_ contact: MeshContact) -> Bool {
        peers.contains { peer in
            peer.isConnected && discoveredCodes[peer.peerID] == contact.code
        }
    }

    func directMessages(with contact: MeshContact) -> [MeshDirectMessage] {
        directMessages
            .filter { $0.senderCode == contact.code || $0.recipientCode == contact.code }
            .sorted { $0.timestamp < $1.timestamp }
    }

    /// Unread messages in the general chat — received from someone else and not yet marked read
    /// by opening that pane. Drives the home status bar's green chat badge.
    var unreadGeneralCount: Int {
        messages.filter { $0.kind == .chat && $0.senderName != displayName && !readGeneralMessageIDs.contains($0.id) }.count
    }

    /// Unread direct messages across all contacts combined. Drives the home status bar's red
    /// chat badge — shown alongside (not instead of) the general-chat green badge, since they're
    /// different channels.
    var unreadDirectCount: Int {
        directMessages.filter { $0.recipientCode == myContactCode && !readDirectMessageIDs.contains($0.id) }.count
    }

    func markGeneralChatRead() {
        readGeneralMessageIDs.formUnion(messages.filter { $0.kind == .chat }.map(\.id))
    }

    func markDirectMessagesRead(with contact: MeshContact) {
        let ids = directMessages(with: contact).filter { $0.recipientCode == myContactCode }.map(\.id)
        readDirectMessageIDs.formUnion(ids)
    }

    func sendDirect(_ text: String, to contact: MeshContact) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let limitedText = String(trimmed.prefix(Self.meshCharacterLimit))

        var message = MeshDirectMessage(
            senderCode: myContactCode,
            senderName: displayName,
            recipientCode: contact.code,
            text: limitedText,
            status: .queued,
            route: .waiting
        )
        if deliverDirect(message) {
            message.status = .sent
            message.route = .mesh
        }
        directMessages.append(message)
    }

    @discardableResult
    private func deliverDirect(_ message: MeshDirectMessage) -> Bool {
        var outgoingMessage = message
        outgoingMessage.status = .sent
        outgoingMessage.route = .mesh
        guard let session,
              let targetPeer = peers.first(where: { $0.isConnected && discoveredCodes[$0.peerID] == message.recipientCode })?.peerID,
              let payload = try? JSONEncoder().encode(outgoingMessage),
              let data = try? JSONEncoder().encode(Envelope(kind: .direct, payload: payload))
        else { return false }

        try? session.send(data, toPeers: [targetPeer], with: .reliable)
        return true
    }

    private func flushQueuedDirectMessages(toward peerID: MCPeerID) {
        guard let code = discoveredCodes[peerID] else { return }
        for index in directMessages.indices {
            guard directMessages[index].status == .queued,
                  directMessages[index].senderCode == myContactCode,
                  directMessages[index].recipientCode == code
            else { continue }

            if deliverDirect(directMessages[index]) {
                directMessages[index].status = .sent
                directMessages[index].route = .mesh
            }
        }
    }

    private func persistContacts() {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        UserDefaults.standard.set(data, forKey: Self.contactsKey)
    }

    // MARK: Identity

    func updateDisplayName(_ newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed != displayName else { return }

        displayName = trimmed
        UserDefaults.standard.set(trimmed, forKey: Self.displayNameKey)
        myPeerID = MCPeerID(displayName: trimmed)

        if isRunning {
            stop()
            start()
        }
    }

    private func addSystemMessage(_ text: String) {
        messages.append(MeshMessage(senderName: "System", text: text, kind: .system))
    }

    private func refreshConnectionState() {
        let connectedCount = peers.filter(\.isConnected).count
        guard isRunning else { state = .idle; return }
        state = connectedCount > 0 ? .connected(connectedCount) : .searching
    }

    private static func randomCallsign() -> String {
        let adjectives = ["Cichy", "Szybki", "Czujny", "Twardy", "Nocny"]
        let nouns = ["Wilk", "Sokół", "Lis", "Orzeł", "Ryś"]
        return "\(adjectives.randomElement()!)-\(nouns.randomElement()!)-\(Int.random(in: 10...99))"
    }

    private static func generateContactCode() -> String {
        // Excludes visually ambiguous characters (0/O, 1/I/L) so codes are easy to read aloud or copy by hand.
        let alphabet = Array("23456789ABCDEFGHJKMNPQRSTUVWXYZ")
        let part1 = String((0..<4).map { _ in alphabet.randomElement()! })
        let part2 = String((0..<4).map { _ in alphabet.randomElement()! })
        return "\(part1)-\(part2)"
    }
}

extension MeshController: MCSessionDelegate {
    nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        Task { @MainActor in
            switch state {
            case .connected:
                if let index = self.peers.firstIndex(where: { $0.peerID == peerID }) {
                    self.peers[index].isConnected = true
                } else {
                    self.peers.append(MeshPeer(peerID: peerID, isConnected: true))
                }
                self.addSystemMessage("\(peerID.displayName) przyłączył się do sieci.")
                self.flushQueuedDirectMessages(toward: peerID)
                self.flushQueuedBroadcastMessages()
            case .connecting:
                if !self.peers.contains(where: { $0.peerID == peerID }) {
                    self.peers.append(MeshPeer(peerID: peerID, isConnected: false))
                }
            case .notConnected:
                if self.peers.contains(where: { $0.peerID == peerID && $0.isConnected }) {
                    self.addSystemMessage("\(peerID.displayName) odłączył się od sieci.")
                }
                self.peers.removeAll { $0.peerID == peerID }
            @unknown default:
                break
            }
            self.refreshConnectionState()
        }
    }

    nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        Task { @MainActor in
            guard let envelope = try? JSONDecoder().decode(Envelope.self, from: data) else { return }
            switch envelope.kind {
            case .broadcast:
                guard let message = try? JSONDecoder().decode(MeshMessage.self, from: envelope.payload),
                      !self.messages.contains(where: { $0.id == message.id })
                else { return }
                self.messages.append(message)
            case .direct:
                guard let message = try? JSONDecoder().decode(MeshDirectMessage.self, from: envelope.payload),
                      message.recipientCode == self.myContactCode,
                      !self.directMessages.contains(where: { $0.id == message.id })
                else { return }
                self.directMessages.append(message)
            }
        }
    }

    nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

extension MeshController: MCNearbyServiceAdvertiserDelegate {
    nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        Task { @MainActor in
            invitationHandler(true, self.session)
        }
    }
}

extension MeshController: MCNearbyServiceBrowserDelegate {
    nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        Task { @MainActor in
            if let code = info?["code"] {
                self.discoveredCodes[peerID] = code
            }
            guard let session = self.session else { return }
            browser.invitePeer(peerID, to: session, withContext: nil, timeout: 10)
        }
    }

    nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        Task { @MainActor in
            self.discoveredCodes.removeValue(forKey: peerID)
        }
    }
}
