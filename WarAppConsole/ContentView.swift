import SwiftUI

struct ContentView: View {
    @State private var store = ConsoleStore()
    @State private var title = ""
    @State private var message = ""
    @State private var severity = "important"
    @State private var location = ""

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 16) {
                serverSection
                Divider()
                newAlertForm
                Spacer()
            }
            .padding()
            .frame(minWidth: 300)
        } detail: {
            alertList
        }
        .task {
            store.startPolling()
        }
        .onDisappear {
            store.stopPolling()
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Serwer")
                .font(.headline)
            TextField("Adres serwera", text: $store.serverURLString)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Odśwież teraz") {
                    Task { await store.refresh() }
                }
                if store.isLoading {
                    ProgressView().controlSize(.small)
                }
            }

            if let error = store.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var newAlertForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Nowy alert")
                .font(.headline)

            TextField("Tytuł", text: $title)
                .textFieldStyle(.roundedBorder)
            TextField("Treść", text: $message, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            TextField("Lokalizacja (opcjonalnie)", text: $location)
                .textFieldStyle(.roundedBorder)

            Picker("Poziom", selection: $severity) {
                Text("Ważny").tag("important")
                Text("Krytyczny").tag("critical")
            }
            .pickerStyle(.segmented)

            Button("Wyślij alert") {
                Task {
                    await store.createAlert(
                        title: title,
                        message: message,
                        severity: severity,
                        location: location.isEmpty ? nil : location
                    )
                    title = ""
                    message = ""
                    location = ""
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(title.isEmpty || message.isEmpty)
        }
    }

    private var alertList: some View {
        List(store.alerts) { alert in
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(alert.severity == "critical" ? Color.red : Color.orange)
                    .frame(width: 10, height: 10)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text(alert.title)
                        .font(.headline)
                    Text(alert.message)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        if let location = alert.location {
                            Label(location, systemImage: "mappin.and.ellipse")
                        }
                        Text(alert.createdAt.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    Text(lifecycleLabel(alert.lifecycle))
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(lifecycleColor(alert.lifecycle).opacity(0.2))
                        .foregroundStyle(lifecycleColor(alert.lifecycle))
                        .clipShape(Capsule())

                    HStack(spacing: 8) {
                        if alert.lifecycle != "expired" {
                            Button("Wygaś") {
                                Task { await store.updateLifecycle(alert, to: "expired") }
                            }
                            .font(.caption)
                        }
                        Button("Usuń", role: .destructive) {
                            Task { await store.delete(alert) }
                        }
                        .font(.caption)
                    }
                }
            }
            .padding(.vertical, 6)
        }
        .navigationTitle("Alerty — sztab kryzysowy")
        .overlay {
            if store.alerts.isEmpty {
                ContentUnavailableView(
                    "Brak alertów",
                    systemImage: "checkmark.shield",
                    description: Text("Dodaj pierwszy alert w panelu po lewej.")
                )
            }
        }
    }

    private func lifecycleLabel(_ lifecycle: String) -> String {
        switch lifecycle {
        case "pending": return "Oczekuje"
        case "confirmed": return "Potwierdzony"
        case "expired": return "Wygasły"
        default: return lifecycle
        }
    }

    private func lifecycleColor(_ lifecycle: String) -> Color {
        switch lifecycle {
        case "pending": return .orange
        case "confirmed": return .green
        case "expired": return .gray
        default: return .secondary
        }
    }
}

#Preview {
    ContentView()
}
