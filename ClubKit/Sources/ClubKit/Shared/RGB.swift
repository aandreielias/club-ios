/// A brand colour as the server sends it (`#RRGGBB`), channels 0...1.
public struct RGB: Decodable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init?(hex: String) {
        guard hex.count == 7, hex.first == "#", let value = UInt32(hex.dropFirst(), radix: 16) else { return nil }
        red = Double((value >> 16) & 0xFF) / 255
        green = Double((value >> 8) & 0xFF) / 255
        blue = Double(value & 0xFF) / 255
    }

    public init(from decoder: Decoder) throws {
        let hex = try decoder.singleValueContainer().decode(String.self)
        guard let rgb = RGB(hex: hex) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not #RRGGBB: \(hex)"))
        }
        self = rgb
    }
}
