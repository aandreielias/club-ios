/// The signed-in member (`GET /api/v1/me`).
public struct Me: Decodable, Sendable {
    public let member: Member
    /// Profile fields the app must ask for before anything else works (today `birthDate`).
    public let missing: [String]
    public let teams: [Team]
    /// Minors the member acts for, with their names.
    public let wardIds: [String]
    public let wardNames: [String: String]

    public struct Member: Decodable, Sendable {
        public let id: String
        public let firstName: String
    }

    public struct Team: Decodable, Sendable {
        public let id: String
        public let name: String
    }
}

/// The fields of `PATCH /api/v1/members/{id}` the app sends; nil ones are left out.
public struct ProfileBody: Encodable, Sendable {
    /// `yyyy-MM-dd`.
    public var birthDate: String?

    public init(birthDate: String? = nil) {
        self.birthDate = birthDate
    }
}

extension ApiClient {
    public func me() async throws -> Me {
        try await get("/api/v1/me")
    }

    public func updateProfile(of memberId: String, _ body: ProfileBody) async throws {
        try await patch("/api/v1/members/\(memberId)", body)
    }
}
