import SwiftUI

struct AddAlertView: View {
    let store: AlertStore

    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var message = ""
    @State private var location = ""
    @State private var severity: AlertSeverity = .important

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Zgłoszenie trafi do weryfikacji przez sztab kryzysowy. Dopiero po potwierdzeniu będzie widoczne dla wszystkich użytkowników.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Poziom ważności") {
                    Picker("Poziom ważności", selection: $severity) {
                        ForEach(AlertSeverity.allCases) { level in
                            Text(level.label).tag(level)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Szczegóły") {
                    TextField("Tytuł, np. \"Zerwana linia energetyczna\"", text: $title)
                    TextField("Opis sytuacji", text: $message, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Lokalizacja (opcjonalnie)", text: $location)
                }

                Section {
                    Button {
                        store.submit(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            message: message.trimmingCharacters(in: .whitespacesAndNewlines),
                            severity: severity,
                            location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location
                        )
                        dismiss()
                    } label: {
                        Text("Wyślij do weryfikacji")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Zgłoś alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Zamknij") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    AddAlertView(store: AlertStore())
}
