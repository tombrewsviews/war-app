import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case server(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Nieprawidłowy adres serwera."
        case .server(let code): return "Serwer odpowiedział kodem \(code)."
        }
    }
}

/// Thin JSON client for the WarAppServer console API. Points at a configurable base URL so the
/// console can talk to a server running on this Mac now, and a remotely hosted one later.
struct APIClient {
    var baseURL: URL

    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    func fetchAlerts() async throws -> [AlertDTO] {
        try await get("/alerts")
    }

    func createAlert(_ request: AlertCreateRequest) async throws -> AlertDTO {
        try await post("/alerts", body: request)
    }

    func updateLifecycle(id: UUID, lifecycle: String) async throws -> AlertDTO {
        try await patch("/alerts/\(id.uuidString)/lifecycle", body: AlertLifecycleUpdateRequest(lifecycle: lifecycle))
    }

    func deleteAlert(id: UUID) async throws {
        var request = URLRequest(url: baseURL.appendingPathComponent("alerts/\(id.uuidString)"))
        request.httpMethod = "DELETE"
        let (_, response) = try await URLSession.shared.data(for: request)
        try validate(response)
    }

    private func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await URLSession.shared.data(from: baseURL.appendingPathComponent(String(path.dropFirst())))
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func patch<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var request = URLRequest(url: baseURL.appendingPathComponent(String(path.dropFirst())))
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        let (data, response) = try await URLSession.shared.data(for: request)
        try validate(response)
        return try decoder.decode(T.self, from: data)
    }

    private func validate(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            throw APIError.server(http.statusCode)
        }
    }
}
