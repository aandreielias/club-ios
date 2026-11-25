import Foundation

/// A brand colour as the server sends it (`#RRGGBB`), channels 0...1.
public struct RGB: Decodable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double

    public static let white = RGB(red: 1, green: 1, blue: 1)

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

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

/// WCAG contrast, ported from club-client `lib/theme/contrast.ts` so both apps derive the same dark mode from the brand.
extension RGB {
    private var luminance: Double {
        func linear(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    /// 1 (same) to 21 (black on white).
    public func contrast(_ other: RGB) -> Double {
        let (a, b) = (luminance, other.luminance)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// `share` (0...1) of `other` mixed in.
    public func mix(_ other: RGB, _ share: Double) -> RGB {
        RGB(red: red + (other.red - red) * share, green: green + (other.green - green) * share, blue: blue + (other.blue - blue) * share)
    }

    /// Lighter with hue and saturation kept (so the brand stays recognisable) until it reaches `ratio` on `background`.
    public func readable(on background: RGB, ratio: Double = 4.5) -> RGB {
        if contrast(background) >= ratio { return self }
        let (h, s, l) = hsl
        for light in stride(from: l, through: 1, by: 0.02) {
            let candidate = RGB(h: h, s: s, l: light)
            if candidate.contrast(background) >= ratio { return candidate }
        }
        return .white
    }

    /// White or `ink` as text on a filled area of this colour, whichever reads better.
    public func textOn(ink: RGB) -> RGB {
        RGB.white.contrast(self) >= ink.contrast(self) ? .white : ink
    }

    private var hsl: (Double, Double, Double) {
        let (hi, lo) = (max(red, green, blue), min(red, green, blue))
        let l = (hi + lo) / 2, d = hi - lo
        guard d > 0 else { return (0, 0, l) }
        let s = d / (1 - abs(2 * l - 1))
        let h = hi == red ? ((green - blue) / d).truncatingRemainder(dividingBy: 6) : hi == green ? (blue - red) / d + 2 : (red - green) / d + 4
        return ((h * 60 + 360).truncatingRemainder(dividingBy: 360), s, l)
    }

    private init(h: Double, s: Double, l: Double) {
        func f(_ n: Double) -> Double {
            let k = (n + h / 30).truncatingRemainder(dividingBy: 12)
            let value = l - s * min(l, 1 - l) * max(-1, min(k - 3, 9 - k, 1))
            return (value * 255).rounded() / 255  // whole channels, like the web's hex
        }
        self.init(red: f(0), green: f(8), blue: f(4))
    }
}
