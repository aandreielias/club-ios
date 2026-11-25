import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// German texts of the server's error codes, as club-client shows them (`Contract/error-texts.json`, written by
/// `scripts/error-texts.mjs` from club-client's catalogs). Unknown codes fall back by HTTP status.
public struct ErrorTexts: Sendable {
    private let codes: [String: String]
    private let status: [String: String]
    private let unknown: String

    public init(json: Data) throws {
        let file = try JSONDecoder().decode(File.self, from: json)
        codes = file.codes
        status = file.status
        unknown = file.unknown
    }

    /// Like club-client's `ErrorMessages.text`: the code's text plus the problem's details, and the reference on server faults.
    public func text(_ error: Error) -> String {
        guard let problem = error as? ProblemError else {
            if let url = error as? URLError {
                return codes[url.code == .timedOut ? "timeout" : "network"] ?? unknown
            }
            return unknown
        }
        let message = problem.code.flatMap { codes[$0] } ?? status[String(problem.status)] ?? "\(unknown) (\(problem.code ?? String(problem.status)))"
        let text = problem.details.isEmpty ? message : "\(message) \(problem.details.joined(separator: ", "))"
        guard let ref = problem.correlationId, problem.status >= 500 else { return text }
        return "\(text) Ref: \(ref)"
    }

    /// Whether the code has a text (the test checks every code the server answers).
    public func knows(_ code: String) -> Bool { codes[code] != nil }

    private struct File: Decodable {
        let codes: [String: String]
        let status: [String: String]
        let unknown: String
    }
}
