import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import ClubKit

private let base = URL(string: "https://api.example.club")!

private func client(status: Int, body: String, seen: @escaping @Sendable (URLRequest) -> Void = { _ in }) -> ApiClient {
    ApiClient(baseURL: base, transport: { request in
        seen(request)
        return (Data(body.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    })
}

@Test func decodesClub() async throws {
    let json = """
        {"name":"SDG Vienna","brand":{"primary":"#5E6AD2","headingCaps":true},"assets":{"logo":null}}
        """
    let club = try await client(status: 200, body: json) { #expect($0.url?.absoluteString == "https://api.example.club/api/v1/club") }.club()
    #expect(club.name == "SDG Vienna")
    #expect(club.brand.primary == RGB(hex: "#5E6AD2"))
    #expect(club.assets.logo == nil)
}

@Test func errorAnswerBecomesProblem() async {
    let body = #"{"status":404,"code":"meeting.not-found","correlationId":"c1"}"#
    await #expect(throws: ProblemError.self) {
        let _: Club = try await client(status: 404, body: body).get("/api/v1/club")
    }
    let problem = ProblemError(status: 404, body: Data(body.utf8))
    #expect(problem.code == "meeting.not-found")
    #expect(problem.correlationId == "c1")
    #expect(ProblemError(status: 502, body: Data("<html>".utf8)).code == nil)
}

@Test func sendsTokenAndBody() async throws {
    let seen = Seen()
    let api = ApiClient(baseURL: base, token: { "t1" }) { request in
        seen.request = request
        return (Data("{}".utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
    try await api.updateProfile(of: "m1", ProfileBody(birthDate: "2010-05-01"))
    let request = try #require(seen.request)
    #expect(request.httpMethod == "PATCH")
    #expect(request.url?.path == "/api/v1/members/m1")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer t1")
    #expect(request.httpBody == Data(#"{"birthDate":"2010-05-01"}"#.utf8))
}

private final class Seen: @unchecked Sendable {
    var request: URLRequest?
}

@Test func resolvesServerPaths() {
    #expect(client(status: 200, body: "").url("/api/v1/club/assets/logo?v=k1").absoluteString
        == "https://api.example.club/api/v1/club/assets/logo?v=k1")
}

@Test func parsesHexColours() {
    #expect(RGB(hex: "#FF8000") == RGB(hex: "#ff8000"))
    #expect(RGB(hex: "#FF8000")?.green == 128.0 / 255)
    #expect(RGB(hex: "FF8000") == nil)
    #expect(RGB(hex: "#FFF") == nil)
    #expect(RGB(hex: "#GG0000") == nil)
}
