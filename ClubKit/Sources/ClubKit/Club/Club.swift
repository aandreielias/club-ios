/// The club's public facts and look (`GET /api/v1/club`). Only the fields the app reads.
public struct Club: Decodable, Sendable {
    public let name: String
    public let brand: Brand
    public let assets: Assets

    public struct Brand: Decodable, Sendable {
        public let primary: RGB
        public let headingCaps: Bool
    }

    /// Server paths of the club's images, null while a slot is empty.
    public struct Assets: Decodable, Sendable {
        public let logo: String?
    }
}

extension ApiClient {
    public func club() async throws -> Club { try await get("/api/v1/club") }
}
