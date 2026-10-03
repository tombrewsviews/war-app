import SwiftUI

struct CommunicationView: View {
    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var generalMessageText = ""
    @State private var showRenameSheet = false
    @State private var showAddContactSheet = false
    @FocusState private var isGeneralInputFocused: Bool
    @Namespace private var contactNamespace

    private var controller: MeshController { appEnvironment.meshController }
    private var reporter: BackendReporter { appEnvironment.backendReporter }
    private var remainingGeneralCharacters: Int { MeshController.meshCharacterLimit - generalMessageText.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                controlPanel
                contactsSection
                generalChatPane
            }
            .padding()
        }
        .navigationTitle("Komunikacja Mesh")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showRenameSheet) {
            RenameCallsignSheet(controller: controller)
        }
        .sheet(isPresented: $showAddContactSheet) {
            AddContactSheet(controller: controller)
        }
        .onAppear { controller.markGeneralChatRead() }
        .onChange(of: controller.messages.count) { controller.markGeneralChatRead() }
    }

    private var backendStatusText: String {
        guard let lastReportedAt = reporter.lastReportedAt else {
            return "Brak połączenia z serwerem sztabu"
        }
        return "Zgłoszono do sztabu: \(lastReportedAt.formatted(date: .omitted, time: .shortened))"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Komunikacja Mesh")
                .font(.largeTitle.weight(.bold))
            Text("Łączy się bezpośrednio z innymi urządzeniami w zasięgu przez Bluetooth/Wi-Fi — bez internetu i infrastruktury sieciowej.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controlPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MeshStatusBadge(state: controller.state)
                Spacer()
                Button {
                    if controller.isRunning {
                        controller.stop()
                    } else {
                        controller.start()
                    }
                } label: {
                    Text(controller.isRunning ? "Zatrzymaj" : "Uruchom")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glass)
                .tint(controller.isRunning ? .red : .blue)
            }

            Divider()

            HStack {
                Label(controller.displayName, systemImage: "person.crop.circle")
                    .font(.footnote.weight(.medium))
                Spacer()
                Button("Zmień") { showRenameSheet = true }
                    .font(.footnote.weight(.semibold))
            }

            Divider()

            Label(backendStatusText, systemImage: reporter.lastReportedAt != nil ? "checkmark.icloud" : "icloud.slash")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassCard(tint: .blue, cornerRadius: 16)
    }

    private var contactsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Kontakty")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    showAddContactSheet = true
                } label: {
                    Label("Dodaj kontakt", systemImage: "person.badge.plus")
                        .font(.caption.weight(.semibold))
                }
            }

            if controller.contacts.isEmpty {
                Text("Nie masz jeszcze żadnych kontaktów. Wymień się kodem z bliską osobą (np. rodziną), żeby móc pisać do niej bezpośrednio przez mesh — niezależnie od czatu ogólnego.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(controller.contacts) { contact in
                        NavigationLink {
                            DirectMessageView(controller: controller, contact: contact)
                                .navigationTransition(.zoom(sourceID: contact.id, in: contactNamespace))
                        } label: {
                            MeshContactRow(contact: contact, isInMesh: controller.isContactInMesh(contact))
                                .matchedTransitionSource(id: contact.id, in: contactNamespace)
                        }
                        .buttonStyle(.tilePress)
                    }
                }
            }
        }
    }

    private var generalChatPane: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Chat ogólny")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if !controller.peers.isEmpty {
                    Text("\(controller.peers.count) w zasięgu")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 10) {
                        if controller.messages.isEmpty {
                            Text("Brak wiadomości. Gdy inne urządzenie z tą aplikacją znajdzie się w zasięgu, połączy się automatycznie.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .padding()
                        } else {
                            ForEach(controller.messages) { message in
                                MeshMessageBubble(message: message, isOwn: message.senderName == controller.displayName)
                            }
                        }
                    }
                    .padding(10)
                }
                .frame(height: 260)

                Divider()

                HStack(spacing: 10) {
                    TextField("Napisz do wszystkich…", text: $generalMessageText, axis: .vertical)
                        .focused($isGeneralInputFocused)
                        .lineLimit(1...3)
                        .padding(8)
                        .glassCard(cornerRadius: 12)
                        .onChange(of: generalMessageText) {
                            generalMessageText = String(generalMessageText.prefix(MeshController.meshCharacterLimit))
                        }

                    Button {
                        controller.send(generalMessageText)
                        generalMessageText = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 26))
                    }
                    .disabled(generalMessageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(10)

                Text("MESH • \(remainingGeneralCharacters)/\(MeshController.meshCharacterLimit) znaków")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(remainingGeneralCharacters < 30 ? .orange : .secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
            .glassCard(cornerRadius: 16)
        }
    }
}

#Preview {
    NavigationStack {
        CommunicationView()
    }
    .environment(AppEnvironment())
}
