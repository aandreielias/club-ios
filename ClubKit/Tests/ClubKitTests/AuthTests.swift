import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ClubKit

/// Records requests and answers them from a queue, like Supabase would.
private final class FakeSupabase: @unchecked Sendable {
    var answers: [(Int, String)] = []
    var requests: [URLRequest] = []
    var stored: Auth.Session?
    var time = Date(timeIntervalSince1970: 1_000_000)

    func auth() -> Auth {
        Auth(url: URL(string: "https://ref.supabase.co")!, publishableKey: "pk", storage: Storage(fake: self),
             transport: { request in
                 self.requests.append(request)
                 let (status, body) = self.answers.removeFirst()
                 return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
             },
             now: { self.time })
    }

    struct Storage: SessionStorage {
        let fake: FakeSupabase
        func load() -> Auth.Session? { fake.stored }
        func save(_ session: Auth.Session?) { fake.stored = session }
    }
}

private func grant(_ access: String, _ refresh: String) -> (Int, String) {
    (200, #"{"access_token":"\#(access)","refresh_token":"\#(refresh)","expires_in":3600,"user":{"email":"a@b.at"}}"#)
}

@Test func signInKeepsTheSession() async throws {
    let fake = FakeSupabase()
    fake.answers = [grant("a1", "r1")]
    let auth = fake.auth()
    try await auth.signIn(email: "a@b.at", password: "pw")
    let request = try #require(fake.requests.first)
    #expect(request.url?.absoluteString == "https://ref.supabase.co/auth/v1/token?grant_type=password")
    #expect(request.value(forHTTPHeaderField: "apikey") == "pk")
    #expect(try await auth.token() == "a1")
    #expect(await auth.email == "a@b.at")
    #expect(fake.stored?.refreshToken == "r1")
    #expect(await fake.auth().email == "a@b.at") // restored from storage
}

@Test func wrongPasswordIsInvalidCredentials() async {
    let fake = FakeSupabase()
    fake.answers = [(400, #"{"code":400,"error_code":"invalid_credentials","msg":"Invalid login credentials"}"#)]
    await #expect(throws: Auth.Failure.invalidCredentials) { try await fake.auth().signIn(email: "a@b.at", password: "x") }
    fake.answers = [(429, "{}")]
    await #expect(throws: Auth.Failure.rateLimited) { try await fake.auth().signIn(email: "a@b.at", password: "x") }
    fake.answers = [(503, "")]
    await #expect(throws: Auth.Failure.unavailable) { try await fake.auth().signIn(email: "a@b.at", password: "x") }
}

@Test func refreshesOnceBeforeExpiry() async throws {
    let fake = FakeSupabase()
    fake.answers = [grant("a1", "r1"), grant("a2", "r2")]
    let auth = fake.auth()
    try await auth.signIn(email: "a@b.at", password: "pw")
    fake.time += 3600 - 30
    async let first = auth.token()
    async let second = auth.token()
    #expect(try await [first, second] == ["a2", "a2"])
    #expect(fake.requests.count == 2)
    #expect(fake.requests[1].url?.absoluteString == "https://ref.supabase.co/auth/v1/token?grant_type=refresh_token")
    #expect(fake.stored?.refreshToken == "r2")
}

@Test func refusedRefreshSignsOut() async throws {
    let fake = FakeSupabase()
    fake.answers = [grant("a1", "r1"), (400, #"{"error_code":"refresh_token_not_found"}"#)]
    let auth = fake.auth()
    try await auth.signIn(email: "a@b.at", password: "pw")
    fake.time += 3600
    #expect(try await auth.token() == nil)
    #expect(await auth.email == nil)
    #expect(fake.stored == nil)
}

@Test func resetMailHidesWhetherTheAddressExists() async throws {
    let fake = FakeSupabase()
    fake.answers = [(400, #"{"error_code":"email_address_invalid"}"#), (429, "{}")]
    try await fake.auth().resetPassword(email: "x@y.at")
    #expect(fake.requests[0].url?.absoluteString == "https://ref.supabase.co/auth/v1/recover")
    await #expect(throws: Auth.Failure.rateLimited) { try await fake.auth().resetPassword(email: "x@y.at") }
}

@Test func signOutEndsTheSessionEvenOffline() async throws {
    let fake = FakeSupabase()
    fake.answers = [grant("a1", "r1"), (503, "")]
    let auth = fake.auth()
    try await auth.signIn(email: "a@b.at", password: "pw")
    await auth.signOut()
    #expect(fake.requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer a1")
    #expect(fake.stored == nil)
    #expect(try await auth.token() == nil)
}
