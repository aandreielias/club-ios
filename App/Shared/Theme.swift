import ClubKit
import SwiftUI
import UIKit

/// The club's brand on screen (Einstellungen › Erscheinungsbild): colours per appearance from `Palette`, the bundled fonts,
/// capitals for headings, corner radius. `.system` before the club is loaded.
struct Theme {
    var accent = Color.accentColor
    var highlight = Color.accentColor
    var text = Color.primary
    var textMuted = Color.secondary
    /// Calm areas behind grouped lists.
    var surface = Color(UIColor.systemGroupedBackground)
    var line = Color(UIColor.separator)
    var headingFamily = Club.Font.system
    var textFamily = Club.Font.system
    var headingCaps = false
    var radius: CGFloat = 8

    static let system = Theme()

    init() {}

    init(_ brand: Club.Brand) {
        let light = Palette(brand, dark: false), dark = Palette(brand, dark: true)
        func color(_ pick: @escaping @Sendable (Palette) -> RGB?, else system: UIColor) -> Color {
            Color(UIColor(dynamicProvider: { traits in
                (pick(traits.userInterfaceStyle == .dark ? dark : light)).map(UIColor.init) ?? system
            }))
        }
        accent = color({ $0.accent }, else: .tintColor)
        highlight = color({ $0.highlight }, else: .tintColor)
        text = color({ $0.text }, else: .label)
        textMuted = color({ $0.textMuted }, else: .secondaryLabel)
        surface = color({ $0.surface }, else: .systemGroupedBackground)
        line = color({ $0.line }, else: .separator)
        headingFamily = brand.headingFont
        textFamily = brand.textFont
        headingCaps = brand.headingCaps
        radius = CGFloat(brand.radiusSmall)
    }

    /// Text in the club's text font, scaled with Dynamic Type.
    func font(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        guard let name = Self.postScriptName(textFamily, weight) else { return .system(style, weight: weight) }
        return .custom(name, size: Self.size(style), relativeTo: style)
    }

    /// Titles in the club's heading font (Anton has one weight, the others take semibold).
    func titleFont(_ style: Font.TextStyle) -> Font {
        guard let name = Self.postScriptName(headingFamily, .semibold) else { return .system(style, weight: .semibold) }
        return .custom(name, size: Self.size(style), relativeTo: style)
    }

    /// Navigation bars are UIKit: large titles in the heading font and accent, inline titles in the text font.
    @MainActor func styleBars() {
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: Self.uiFont(headingFamily, .semibold, .largeTitle), .foregroundColor: UIColor(accent)]
        bar.titleTextAttributes = [.font: Self.uiFont(textFamily, .semibold, .headline)]
    }

    // shortcut: only Inter and Anton are bundled (the fonts of the clubs using the app); Oswald, Roboto and Source Serif
    // show as the system font. Add their TTFs to App/Resources/Fonts (and UIAppFonts) when a club picks one.
    private static func postScriptName(_ font: Club.Font, _ weight: Font.Weight) -> String? {
        switch font {
        case .inter: weight == .bold ? "Inter-Bold" : weight == .semibold ? "Inter-SemiBold" : "Inter-Regular"
        case .anton: "Anton-Regular"
        default: nil
        }
    }

    /// iOS's default sizes (Dynamic Type "large"); `relativeTo` scales from there.
    static func size(_ style: Font.TextStyle) -> CGFloat {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .callout: 16
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }

    private static func uiFont(_ font: Club.Font, _ weight: Font.Weight, _ style: UIFont.TextStyle) -> UIFont {
        let base = UIFont.preferredFont(forTextStyle: style)
        guard let name = postScriptName(font, weight), let custom = UIFont(name: name, size: base.pointSize) else {
            return .systemFont(ofSize: base.pointSize, weight: weight == .semibold ? .semibold : .regular)
        }
        return UIFontMetrics(forTextStyle: style).scaledFont(for: custom)
    }
}

extension EnvironmentValues {
    @Entry var theme = Theme.system
}

extension View {
    /// The club's look, language and time zone for everything below. Root of the signed-in screens and of the snapshots.
    @MainActor func clubStyle(_ club: Club) -> some View {
        let theme = Theme(club.brand)
        theme.styleBars()  // before the first bar exists; setting it again is harmless
        return environment(\.theme, theme)
            .environment(\.locale, Locale(identifier: club.locale))
            .environment(\.timeZone, TimeZone(identifier: club.timeZone) ?? .current)
            .environment(\.calendar, .club(club))
            .tint(theme.accent)
            .foregroundStyle(theme.text)
            .font(theme.font(.body))
            .buttonBorderShape(.roundedRectangle(radius: theme.radius))
    }

    /// A title in the club's heading font, in capitals when the brand says so.
    func heading(_ style: Font.TextStyle) -> some View {
        modifier(Heading(style: style))
    }

    /// Grouped lists and forms on the brand's calm surface.
    func brandSurface() -> some View {
        modifier(BrandSurface())
    }
}

private struct Heading: ViewModifier {
    let style: Font.TextStyle
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .font(theme.titleFont(style))
            .textCase(theme.headingCaps ? .uppercase : nil)
            .tracking(theme.headingCaps ? Theme.size(style) * 0.02 : 0)
            .foregroundStyle(theme.accent)
    }
}

private struct BrandSurface: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content.scrollContentBackground(.hidden).background(theme.surface)
    }
}
