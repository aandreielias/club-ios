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

    public func get<T: Decodable>(_ path: String) async throws -> T {
        try await JSONDecoder().decode(T.self, from: send("GET", path))
    }

    /// Writes whose answer the app does not read.
    public func patch(_ path: String, _ body: some Encodable) async throws {
        _ = try await send("PATCH", path, body: JSONEncoder().encode(body))
    }

    /// Server paths (`/api/v1/...`, also the asset links the server sends) against the API's address.
    public func url(_ path: String) -> URL {
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }

    private func send(_ method: String, _ path: String, body: Data? = nil) async throws -> Data {
        var request = URLRequest(url: url(path))
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
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
