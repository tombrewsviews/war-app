import SwiftUI

enum AlertSeverity: String, CaseIterable, Identifiable {
    case critical
    case important

    var id: String { rawValue }

    var label: String {
        switch self {
        case .critical: return "Krytyczny"
        case .important: return "Ważny"
        }
    }

    var color: Color {
        switch self {
        case .critical: return .red
        case .important: return .orange
        }
    }

    var icon: String {
        switch self {
        case .critical: return "exclamationmark.octagon.fill"
        case .important: return "exclamationmark.triangle.fill"
        }
    }
}

enum AlertLifecycle: Equatable {
    case pending
    case confirmed
    case expired
}

struct AlertItem: Identifiable {
    let id: UUID
    var title: String
    var message: String
    var severity: AlertSeverity
    var lifecycle: AlertLifecycle
    var location: String?
    let createdAt: Date
    var isUserSubmitted: Bool

    init(
        id: UUID = UUID(),
        title: String,
        message: String,
        severity: AlertSeverity,
        lifecycle: AlertLifecycle,
        location: String? = nil,
        createdAt: Date = .now,
        isUserSubmitted: Bool = false
    ) {
        self.id = id
        self.title = title
        self.message = message
        self.severity = severity
        self.lifecycle = lifecycle
        self.location = location
        self.createdAt = createdAt
        self.isUserSubmitted = isUserSubmitted
    }
}

/// Holds the alert feed and drives the "zgłoś alert" review flow: a user-submitted alert starts as
/// `.pending` and is only visible to its author. There's no real crisis-staff backend yet, so
/// verification is simulated locally with a delay; once "confirmed" it joins the public feed that
/// everyone sees, sorted into Krytyczne/Ważne by its severity.
@MainActor
@Observable
final class AlertStore {
    private(set) var alerts: [AlertItem]
    private(set) var seenCriticalAlertIDs: Set<UUID> = []

    init() {
        let now = Date.now
        alerts = [
            AlertItem(
                title: "Nalot – szukaj schronu natychmiast",
                message: "Wykryto nadlatujące obiekty w kierunku dzielnicy Centrum. Natychmiast skieruj się do najbliższego schronu.",
                severity: .critical,
                lifecycle: .confirmed,
                location: "Centrum",
                createdAt: now.addingTimeInterval(-4 * 60)
            ),
            AlertItem(
                title: "Zanieczyszczona woda w sieci wodociągowej",
                message: "Wykryto uszkodzenie sieci wodociągowej. Nie pij wody z kranu do odwołania.",
                severity: .critical,
                lifecycle: .confirmed,
                location: "Dzielnica Wschodnia",
                createdAt: now.addingTimeInterval(-40 * 60)
            ),
            AlertItem(
                title: "Ograniczony dostęp do prądu",
                message: "Wprowadzono rotacyjne wyłączenia zasilania w wybranych dzielnicach w celu oszczędzania energii.",
                severity: .important,
                lifecycle: .confirmed,
                location: "Cała gmina",
                createdAt: now.addingTimeInterval(-2 * 60 * 60)
            ),
            AlertItem(
                title: "Utrudnienia na moście Głównym",
                message: "Most Główny częściowo zamknięty dla ruchu. Szukaj alternatywnej trasy.",
                severity: .important,
                lifecycle: .confirmed,
                location: "Centrum",
                createdAt: now.addingTimeInterval(-5 * 60 * 60)
            ),
            AlertItem(
                title: "Alarm przeciwlotniczy odwołany dla dzielnicy Centrum",
                message: "Zagrożenie minęło. Można bezpiecznie wrócić do normalnych zajęć.",
                severity: .important,
                lifecycle: .expired,
                location: "Centrum",
                createdAt: now.addingTimeInterval(-26 * 60 * 60)
            ),
            AlertItem(
                title: "Tymczasowy punkt wydawania wody – zamknięty",
                message: "Punkt wydawania wody przy ul. Długiej 12 zakończył działalność po zakończeniu dostaw.",
                severity: .critical,
                lifecycle: .expired,
                location: "ul. Długa 12",
                createdAt: now.addingTimeInterval(-2 * 24 * 60 * 60)
            )
        ]
    }

    var criticalAlerts: [AlertItem] {
        alerts.filter { $0.lifecycle == .confirmed && $0.severity == .critical }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Critical alerts not yet marked seen (see `markCriticalAlertsSeen`) — drives the home status
    /// bar's badge count, which should drop to zero once the user has actually looked at them
    /// rather than just showing the total count forever.
    var unseenCriticalCount: Int {
        criticalAlerts.filter { !seenCriticalAlertIDs.contains($0.id) }.count
    }

    func markCriticalAlertsSeen() {
        seenCriticalAlertIDs.formUnion(criticalAlerts.map(\.id))
    }

    var importantAlerts: [AlertItem] {
        alerts.filter { $0.lifecycle == .confirmed && $0.severity == .important }.sorted { $0.createdAt > $1.createdAt }
    }

    var expiredAlerts: [AlertItem] {
        alerts.filter { $0.lifecycle == .expired }.sorted { $0.createdAt > $1.createdAt }
    }

    /// Only the current device's own pending submissions — nobody else can see these yet.
    var pendingAlerts: [AlertItem] {
        alerts.filter { $0.lifecycle == .pending }.sorted { $0.createdAt > $1.createdAt }
    }

    func submit(title: String, message: String, severity: AlertSeverity, location: String?) {
        let item = AlertItem(
            title: title,
            message: message,
            severity: severity,
            lifecycle: .pending,
            location: location,
            isUserSubmitted: true
        )
        alerts.append(item)
        simulateStaffVerification(for: item.id)
    }

    // TODO: replace with a real submission to the crisis-staff backend once it exists.
    private func simulateStaffVerification(for id: UUID) {
        Task {
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let index = alerts.firstIndex(where: { $0.id == id }) else { return }
            alerts[index].lifecycle = .confirmed
        }
    }
}
