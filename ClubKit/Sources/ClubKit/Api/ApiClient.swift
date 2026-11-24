import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Calls club-server's REST API and decodes its JSON answers.
public struct ApiClient: Sendable {
    public typealias Transport = @Sendable (URLRequest) async throws -> (Data, URLResponse)

    public let baseURL: URL
    private let transport: Transport

    public init(baseURL: URL, transport: @escaping Transport = { try await URLSession.shared.data(for: $0) }) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func get<T: Decodable>(_ path: String) async throws -> T {
        let (data, response) = try await transport(URLRequest(url: url(path)))
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw ProblemError(status: status, body: data) }
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Server paths (`/api/v1/...`, also the asset links the server sends) against the API's address.
    public func url(_ path: String) -> URL {
        URL(string: path, relativeTo: baseURL)!.absoluteURL
    }
}
