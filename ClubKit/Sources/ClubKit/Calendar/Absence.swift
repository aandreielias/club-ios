import Foundation

/// A planned absence of the member or a ward: appointments on those days count as "Nein" until answered (`/api/v1/me/absences`).
public struct Absence: Decodable, Sendable, Identifiable {
    public let id: String
    public let memberId: String
    /// `yyyy-MM-dd`, both days included.
    public let from: String
    public let to: String
    /// Seen only by coaches of the member's teams, board and admins (and the member).
    public let reason: String?
}

/// `POST /api/v1/me/absences`; no `memberId` = the member themselves.
public struct AbsenceBody: Encodable, Sendable {
    public let memberId: String?
    public let from: String
    public let to: String
    public let reason: String?

    public init(memberId: String?, from: String, to: String, reason: String?) {
        self.memberId = memberId
        self.from = from
        self.to = to
        self.reason = reason
    }
}

extension ApiClient {
    /// Current and future absences of the member and their wards.
    public func absences() async throws -> [Absence] {
        let answer: Items<Absence> = try await get("/api/v1/me/absences")
        return answer.items
    }

    public func addAbsence(_ body: AbsenceBody, key: String) async throws -> Absence {
        try await post("/api/v1/me/absences", body, key: key)
    }

    public func deleteAbsence(_ id: String) async throws {
        try await delete("/api/v1/me/absences/\(id)")
    }
}
