import SwiftUI

struct MeshStatusBadge: View {
    let state: MeshController.ConnectionState

    private var color: Color {
        switch state {
        case .idle: return .gray
        case .searching: return .orange
        case .connected: return .green
        }
    }

    private var icon: String {
        switch state {
        case .idle: return "antenna.radiowaves.left.and.right.slash"
        default: return "antenna.radiowaves.left.and.right"
        }
    }

    private var text: String {
        switch state {
        case .idle: return "Sieć wyłączona"
        case .searching: return "Szukanie urządzeń…"
        case .connected(let count): return count == 1 ? "Połączono z 1 urządzeniem" : "Połączono z \(count) urządzeniami"
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(color)
    }
}

struct MeshPeerChip: View {
    let peer: MeshPeer

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(peer.isConnected ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
            Text(peer.displayName)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(.blue.opacity(0.3)), in: .capsule)
    }
}

struct MeshMessageBubble: View {
    let message: MeshMessage
    let isOwn: Bool

    var body: some View {
        if message.kind == .system {
            Text(message.text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        } else {
            HStack {
                if isOwn { Spacer(minLength: 40) }

                VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
                    if !isOwn {
                        Text(message.senderName)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Text(message.text)
                        .font(.subheadline)
                        .foregroundStyle(isOwn ? .white : .primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(isOwn ? Color.blue : Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    HStack(spacing: 4) {
                        Text(message.timestamp, style: .time)
                        if isOwn {
                            MessageRouteLabel(route: message.route)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                if !isOwn { Spacer(minLength: 40) }
            }
        }
    }
}

struct RenameCallsignSheet: View {
    let controller: MeshController

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(controller: MeshController) {
        self.controller = controller
        _name = State(initialValue: controller.displayName)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Twój pseudonim w sieci MESH") {
                    TextField("Pseudonim", text: $name)
                }

                Text("Inne urządzenia zobaczą tę nazwę jako nadawcę Twoich wiadomości.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle("Zmień pseudonim")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Zapisz") {
                        controller.updateDisplayName(name)
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct MeshContactRow: View {
    let contact: MeshContact
    let isInMesh: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(contact.nickname.prefix(1).uppercased())
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.blue)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(contact.nickname)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                HStack(spacing: 5) {
                    Circle()
                        .fill(isInMesh ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(isInMesh ? "W zasięgu mesh" : "Poza zasięgiem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .glassCard(cornerRadius: 12, interactive: true)
    }
}

struct AddContactSheet: View {
    let controller: MeshController

    @Environment(\.dismiss) private var dismiss
    @State private var code = ""
    @State private var nickname = ""

    @State private var showScanner = false

    private var canSave: Bool {
        !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Twój kod") {
                    VStack(spacing: 12) {
                        QRCodeView(content: controller.myContactCode)
                            .frame(width: 180, height: 180)
                            .padding(8)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .frame(maxWidth: .infinity)

                    HStack {
                        Text(controller.myContactCode)
                            .font(.system(.title3, design: .monospaced).weight(.bold))
                        Spacer()
                        ShareLink(item: "Mój kod MESH w WarApp: \(controller.myContactCode)") {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }

                    Text("Pokaż ten kod QR bliskiej osobie (np. rodzinie), żeby zeskanowała go telefonem — albo podaj kod ręcznie. Dzięki temu doda Cię jako kontakt i będzie mogła pisać do Ciebie bezpośrednio.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Dodaj kontakt") {
                    HStack {
                        TextField("Kod kontaktu, np. AB12-CD34", text: $code)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()

                        Button {
                            showScanner = true
                        } label: {
                            Image(systemName: "qrcode.viewfinder")
                        }
                    }
                    TextField("Nazwa, np. Mama", text: $nickname)
                }

                Section {
                    Button {
                        controller.addContact(code: code, nickname: nickname)
                        dismiss()
                    } label: {
                        Text("Zapisz kontakt")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSave)
                }
            }
            .navigationTitle("Kontakty MESH")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showScanner) {
                QRScannerSheet { scannedCode in
                    code = scannedCode
                }
            }
        }
    }
}

struct DirectMessageBubble: View {
    let message: MeshDirectMessage
    let isOwn: Bool

    var body: some View {
        HStack {
            if isOwn { Spacer(minLength: 40) }

            VStack(alignment: isOwn ? .trailing : .leading, spacing: 3) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(isOwn ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isOwn ? Color.blue : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                    if isOwn {
                        MessageRouteLabel(route: message.route)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }

            if !isOwn { Spacer(minLength: 40) }
        }
    }
}

private struct MessageRouteLabel: View {
    let route: MessageRoute

    var body: some View {
        Label(title, systemImage: icon)
            .foregroundStyle(color)
    }

    private var title: String {
        switch route {
        case .waiting: "Oczekuje na połączenie"
        case .mesh: "Wysłano przez MESH"
        case .internet: "Wysłano przez Internet"
        }
    }

    private var icon: String {
        switch route {
        case .waiting: "clock"
        case .mesh: "antenna.radiowaves.left.and.right"
        case .internet: "network"
        }
    }

    private var color: Color {
        switch route {
        case .waiting: .orange
        case .mesh: .green
        case .internet: .blue
        }
    }
}
