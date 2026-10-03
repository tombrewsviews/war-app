import SwiftUI

struct DirectMessageView: View {
    let controller: MeshController
    let contact: MeshContact

    @State private var messageText = ""
    @FocusState private var isInputFocused: Bool

    private var isInMesh: Bool { controller.isContactInMesh(contact) }
    private var remainingCharacters: Int { MeshController.meshCharacterLimit - messageText.count }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 10) {
                    let history = controller.directMessages(with: contact)
                    if history.isEmpty {
                        Text("Brak wiadomości. Napisz coś do \(contact.nickname).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(history) { message in
                            DirectMessageBubble(message: message, isOwn: message.senderCode == controller.myContactCode)
                        }
                    }
                }
                .padding()
            }
            .onTapGesture { isInputFocused = false }

            Divider()

            inputBar
        }
        .navigationTitle(contact.nickname)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(isInMesh ? Color.green : Color.gray)
                        .frame(width: 7, height: 7)
                    Text(isInMesh ? "W zasięgu" : "Poza zasięgiem")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { controller.markDirectMessagesRead(with: contact) }
        .onChange(of: controller.directMessages.count) { controller.markDirectMessagesRead(with: contact) }
    }

    private var inputBar: some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack(spacing: 10) {
                TextField("Napisz do \(contact.nickname)…", text: $messageText, axis: .vertical)
                    .focused($isInputFocused)
                    .lineLimit(1...4)
                    .padding(10)
                    .glassCard(cornerRadius: 14)
                    .onChange(of: messageText) {
                        messageText = String(messageText.prefix(MeshController.meshCharacterLimit))
                    }

                Button {
                    controller.sendDirect(messageText, to: contact)
                    messageText = ""
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 30))
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            Text("MESH • \(remainingCharacters)/\(MeshController.meshCharacterLimit) znaków")
                .font(.caption2.weight(.medium))
                .foregroundStyle(remainingCharacters < 30 ? .orange : .secondary)
        }
        .padding()
        .background(.bar)
    }
}

#Preview {
    NavigationStack {
        DirectMessageView(controller: MeshController(), contact: MeshContact(nickname: "Mama", code: "AB12-CD34"))
    }
}
