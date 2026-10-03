import SwiftUI

struct AlertView: View {
    private enum Segment: String, CaseIterable, Identifiable {
        case critical = "Krytyczne"
        case important = "Ważne"
        case expired = "Wygasłe"

        var id: String { rawValue }
    }

    @Environment(AppEnvironment.self) private var appEnvironment
    @State private var segment: Segment = .critical
    @State private var showAddAlert = false

    private var store: AlertStore { appEnvironment.alertStore }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                SirenSignalsShortcut()

                if !store.pendingAlerts.isEmpty {
                    pendingSection
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Picker("Kategoria", selection: $segment) {
                    ForEach(Segment.allCases) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)

                alertList
                    .id(segment)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
            }
            .padding()
            .animation(.snappy, value: segment)
            .animation(.snappy, value: store.pendingAlerts.count)
        }
        .navigationTitle("Alerty")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddAlert = true
                } label: {
                    Label("Dodaj alert", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showAddAlert) {
            AddAlertView(store: store)
        }
        .onAppear { store.markCriticalAlertsSeen() }
        .onChange(of: segment) { _, newValue in
            if newValue == .critical { store.markCriticalAlertsSeen() }
        }
        .onChange(of: store.criticalAlerts.count) {
            if segment == .critical { store.markCriticalAlertsSeen() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Alerty")
                .font(.largeTitle.weight(.bold))
            Text("Krytyczne i ważne komunikaty potwierdzone przez sztab kryzysowy. Widzisz coś niepotwierdzone? Zgłoś to poniżej.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Twoje zgłoszenia")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(store.pendingAlerts) { item in
                    PendingAlertCard(item: item)
                }
            }
        }
    }

    @ViewBuilder
    private var alertList: some View {
        switch segment {
        case .critical:
            alertGroup(store.criticalAlerts, isExpired: false, emptyText: "Brak krytycznych alertów. Wróć tu, jeśli sytuacja się zmieni.")
        case .important:
            alertGroup(store.importantAlerts, isExpired: false, emptyText: "Brak ważnych alertów w tej chwili.")
        case .expired:
            alertGroup(store.expiredAlerts, isExpired: true, emptyText: "Brak wygasłych alertów.")
        }
    }

    private func alertGroup(_ items: [AlertItem], isExpired: Bool, emptyText: String) -> some View {
        Group {
            if items.isEmpty {
                EmptyAlertsPlaceholder(text: emptyText)
            } else {
                VStack(spacing: 10) {
                    ForEach(items) { item in
                        AlertCard(item: item, isExpired: isExpired)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        AlertView()
    }
    .environment(AppEnvironment())
}
