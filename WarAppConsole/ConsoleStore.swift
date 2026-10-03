import Foundation

@MainActor
@Observable
final class ConsoleStore {
    private(set) var alerts: [AlertDTO] = []
    private(set) var isLoading = false
    var errorMessage: String?
    var serverURLString: String = "http://localhost:8080" {
        didSet { client = APIClient(baseURL: URL(string: serverURLString) ?? client.baseURL) }
    }

    @ObservationIgnored private var client = APIClient(baseURL: URL(string: "http://localhost:8080")!)
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    func startPolling() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        do {
            alerts = try await client.fetchAlerts().sorted { $0.createdAt > $1.createdAt }
            errorMessage = nil
        } catch {
            errorMessage = "Nie udało się połączyć z serwerem: \(error.localizedDescription)"
        }
    }

    func createAlert(title: String, message: String, severity: String, location: String?) async {
        do {
            _ = try await client.createAlert(AlertCreateRequest(title: title, message: message, severity: severity, location: location))
            await refresh()
        } catch {
            errorMessage = "Nie udało się dodać alertu: \(error.localizedDescription)"
        }
    }

    func updateLifecycle(_ alert: AlertDTO, to lifecycle: String) async {
        do {
            _ = try await client.updateLifecycle(id: alert.id, lifecycle: lifecycle)
            await refresh()
        } catch {
            errorMessage = "Nie udało się zaktualizować statusu: \(error.localizedDescription)"
        }
    }

    func delete(_ alert: AlertDTO) async {
        do {
            try await client.deleteAlert(id: alert.id)
            await refresh()
        } catch {
            errorMessage = "Nie udało się usunąć alertu: \(error.localizedDescription)"
        }
    }
}
