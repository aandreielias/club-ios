import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Calls club-server's REST API with the member's token and decodes its JSON answers.
public struct ApiClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)
    public typealias Token = @Sendable () async throws -> String?

    public let baseURL: URL
    private let token: Token
    private let transport: Transport

    public init(baseURL: URL, token: @escaping Token = { nil }, transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    public func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        try await Self.decoder().decode(T.self, from: send("GET", path, query: query))
    }

    /// Writes whose answer the app does not read.
    public func put(_ path: String, _ body: some Encodable) async throws {
        _ = try await send("PUT", path, body: JSONEncoder().encode(body))
    }

    /// Writes that answer with the changed record.
    public func put<T: Decodable>(_ path: String, _ body: some Encodable) async throws -> T {
        try await Self.decoder().decode(T.self, from: send("PUT", path, body: JSONEncoder().encode(body)))
    }

    /// Writes whose answer the app does not read.
    public func patch(_ path: String, _ body: some Encodable) async throws {
        _ = try await send("PATCH", path, body: JSONEncoder().encode(body))
    }

    /// Creates something. `key` is the Idempotency-Key: one per logical POST, sent again when the same POST is retried.
    public func post<T: Decodable>(_ path: String, _ body: some Encodable, key: String) async throws -> T {
        try await Self.decoder().decode(T.self, from: send("POST", path, body: JSONEncoder().encode(body), key: key))
    }

    /// Actions without body or answer that may simply run again (e.g. mark all read).
    public func post(_ path: String) async throws {
        _ = try await send("POST", path)
    }

    public func delete(_ path: String) async throws {
        _ = try await send("DELETE", path)
    }

    /// Server paths (`/api/v1/...`, also the asset links the server sends) against the API's address.
    public func url(_ path: String) -> URL {
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }

    /// API times are UTC instants, with or without fractions of a second.
    public static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = (try? Date(text, strategy: .iso8601)) ?? (try? Date(text, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true))) {
                return date
            }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not an instant: \(text)"))
        }
        return decoder
    }

    /// Query values as the server reads them (instants in ISO 8601).
    public static func instant(_ date: Date) -> String {
        date.formatted(.iso8601)
    }

    private func send(_ method: String, _ path: String, query: [String: String] = [:], body: Data? = nil, key: String? = nil) async throws -> Data {
        var components = URLComponents(url: url(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty {
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let key {
            request.setValue(key, forHTTPHeaderField: "Idempotency-Key")
        }
        if let token = try await token() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        let (data, response) = try await transport(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ProblemError(status: status, body: data) }
        return data
    }
}
