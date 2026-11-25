/// The brand's colours for one appearance, as club-client's `ThemeService.branded` derives them.
/// Light mode takes the brand as it is; dark mode keeps the system's surfaces and text and lightens the brand colours
/// until they read on the dark background. Nil = the system's own colour.
public struct Palette: Equatable, Sendable {
    public let accent: RGB
    public let accentHover: RGB
    /// Small marks (3:1 is enough for graphics).
    public let highlight: RGB
    /// Text on filled accent areas.
    public let onAccent: RGB
    public let text: RGB?
    public let textMuted: RGB?
    public let surface: RGB?
    public let line: RGB?

    public init(_ brand: Club.Brand, dark: Bool) {
        guard dark else {
            self.init(accent: brand.primary, accentHover: brand.primaryHover, highlight: brand.accent,
                      onAccent: brand.primary.textOn(ink: brand.text), text: brand.text, textMuted: brand.textMuted,
                      surface: brand.tint, line: brand.line)
            return
        }
        let onPage = brand.primary.readable(on: Palette.darkSurface)
        // A mid-light accent can leave neither white nor ink at 4.5:1 on buttons; then lighten until the ink reads on it.
        let accent = onPage.textOn(ink: brand.text).contrast(onPage) >= 4.5 ? onPage : brand.primary.readable(on: brand.text)
        self.init(accent: accent, accentHover: accent.mix(.white, 0.12), highlight: brand.accent.readable(on: Palette.darkSurface, ratio: 3),
                  onAccent: accent.textOn(ink: brand.text), text: nil, textMuted: nil, surface: nil, line: nil)
    }

    private init(accent: RGB, accentHover: RGB, highlight: RGB, onAccent: RGB, text: RGB?, textMuted: RGB?, surface: RGB?, line: RGB?) {
        self.accent = accent
        self.accentHover = accentHover
        self.highlight = highlight
        self.onAccent = onAccent
        self.text = text
        self.textMuted = textMuted
        self.surface = surface
        self.line = line
    }

    /// iOS dark grouped cells (`secondarySystemGroupedBackground`), the lightest dark surface text sits on.
    static let darkSurface = RGB(hex: "#1C1C1E")!
}
