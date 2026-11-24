import Foundation

/// An error answer of the server (RFC 9457 with `code` and `correlationId`).
public struct ProblemError: Error, Equatable, Sendable {
    public let status: Int
    public let code: String?
    public let details: [String]
    public let correlationId: String?

    init(status: Int, body: Data) {
        let problem = try? JSONDecoder().decode(Body.self, from: body)
        self.status = status
        code = problem?.code
        details = problem?.details ?? []
        correlationId = problem?.correlationId
    }

    private struct Body: Decodable {
        let code: String?
        let details: [String]?
        let correlationId: String?
    }
}
