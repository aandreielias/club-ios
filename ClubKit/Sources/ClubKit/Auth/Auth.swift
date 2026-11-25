import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Keeps the login session (the app: the Keychain).
public protocol SessionStorage: Sendable {
    func load() -> Auth.Session?
    func save(_ session: Auth.Session?)
}

/// Login through Supabase Auth's REST API, the calls `@supabase/auth-js` makes for the web: password sign-in,
/// refresh shortly before the access token expires, the reset mail and sign-out.
public actor Auth {
    public struct Session: Codable, Equatable, Sendable {
        public let accessToken: String
        public let refreshToken: String
        public let expiresAt: Date
        public let email: String
    }

    public enum Failure: Error, Equatable {
        case invalidCredentials
        case rateLimited
        /// Any other refusal (e.g. a blocked account or a dead refresh token).
        case rejected
        case unavailable
    }

    private let url: URL
    private let publishableKey: String
    private let storage: any SessionStorage
    private let transport: ApiClient.Transport
    private let now: @Sendable () -> Date
    private var session: Session?
    private var refreshing: Task<Session, Error>?

    public init(
        url: URL, publishableKey: String, storage: any SessionStorage,
        transport: @escaping ApiClient.Transport = { try await URLSession.shared.data(for: $0) },
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.url = url
        self.publishableKey = publishableKey
        self.storage = storage
        self.transport = transport
        self.now = now
        session = storage.load()
    }

    /// The signed-in address; nil when signed out.
    public var email: String? { session?.email }

    public func signIn(email: String, password: String) async throws {
        keep(try await grant("password", ["email": email, "password": password]))
    }

    /// Ends the session at Supabase when reachable; signed out locally in any case.
    public func signOut() async {
        if let token = session?.accessToken { _ = try? await post("logout", [:], bearer: token) }
        keep(nil)
    }

    /// Sends the reset mail (its link opens the web app, Supabase's Site URL). Only rate limits are reported,
    /// since other errors would tell whether the address exists.
    public func resetPassword(email: String) async throws {
        do { _ = try await post("recover", ["email": email]) } catch Failure.rateLimited { throw Failure.rateLimited } catch {}
    }

    /// The current access token, refreshed when it expires within a minute; nil when signed out.
    /// A refused refresh signs out. Concurrent callers share one refresh (Supabase refresh tokens are single-use).
    public func token() async throws -> String? {
        guard let current = session else { return nil }
        if current.expiresAt > now().addingTimeInterval(60) { return current.accessToken }
        let task = refreshing ?? Task { try await grant("refresh_token", ["refresh_token": current.refreshToken]) }
        refreshing = task
        defer { refreshing = nil }
        do {
            let fresh = try await task.value
            keep(fresh)
            return fresh.accessToken
        } catch Failure.invalidCredentials, Failure.rejected {
            keep(nil)
            return nil
        }
    }

    private func keep(_ session: Session?) {
        self.session = session
        storage.save(session)
    }

    private func grant(_ type: String, _ body: [String: String]) async throws -> Session {
        let answer = try await JSONDecoder().decode(Grant.self, from: post("token?grant_type=\(type)", body))
        return Session(
            accessToken: answer.access_token, refreshToken: answer.refresh_token,
            expiresAt: now().addingTimeInterval(answer.expires_in), email: answer.user.email)
    }

    private func post(_ path: String, _ body: [String: String], bearer: String? = nil) async throws -> Data {
        var request = URLRequest(url: URL(string: "auth/v1/\(path)", relativeTo: url)!.absoluteURL)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        if let bearer { request.setValue("Bearer \(bearer)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await transport(request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        switch status {
        case 200..<300: return data
        case 429: throw Failure.rateLimited
        case 400..<500:
            let error = try? JSONDecoder().decode(ErrorBody.self, from: data)
            let wrongLogin = error?.error_code == "invalid_credentials" || error?.error == "invalid_grant"
            throw wrongLogin ? Failure.invalidCredentials : Failure.rejected
        default: throw Failure.unavailable
        }
    }

    private struct Grant: Decodable {
        let access_token: String
        let refresh_token: String
        let expires_in: Double
        let user: User
        struct User: Decodable { let email: String }
    }

    private struct ErrorBody: Decodable {
        let error_code: String?
        let error: String?
    }
}
