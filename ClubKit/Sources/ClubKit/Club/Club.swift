/// The club's public facts and look (`GET /api/v1/club`). Only the fields the app reads.
public struct Club: Decodable, Sendable {
    public let name: String
    /// IANA zone and BCP 47 locale every date is shown in (fixed in the server's `club.yml`).
    public let timeZone: String
    public let locale: String
    public let brand: Brand
    public let assets: Assets

    /// The look the board sets in Einstellungen › Erscheinungsbild (club.yml until then).
    public struct Brand: Decodable, Sendable {
        /// Buttons, links, active entries.
        public let primary: RGB
        public let primaryHover: RGB
        /// Small marks only (active marker, unread dot), never areas or text.
        public let accent: RGB
        public let text: RGB
        public let textMuted: RGB
        /// Calm areas.
        public let tint: RGB
        /// Borders and dividers.
        public let line: RGB
        public let headingFont: Font
        public let textFont: Font
        /// Titles in capitals with slight letter spacing.
        public let headingCaps: Bool
        public let radiusSmall: Int
        public let radiusLarge: Int
    }

    /// The fonts a club may pick (`Brand.Font` on the server).
    public enum Font: String, Decodable, Sendable {
        case inter = "INTER", anton = "ANTON", oswald = "OSWALD", roboto = "ROBOTO", sourceSerif = "SOURCE_SERIF", system = "SYSTEM"

        /// A font added to the server later shows as the system font instead of failing the whole club.
        public init(from decoder: Decoder) throws {
            self = Font(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .system
        }
    }

    /// Server paths of the club's images, null while a slot is empty.
    public struct Assets: Decodable, Sendable {
        public let logo: String?
    }
}

extension ApiClient {
    public func club() async throws -> Club { try await get("/api/v1/club") }
}
