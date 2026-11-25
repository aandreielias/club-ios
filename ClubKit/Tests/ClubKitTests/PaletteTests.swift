import Foundation
import Testing
@testable import ClubKit

/// The SDG brand guide's values (design/brand/tokens), as a club would enter them in Erscheinungsbild.
let sdgClub = """
    {"name":"SDG Vienna","timeZone":"Europe/Vienna","locale":"de-AT","assets":{"logo":null},
     "brand":{"primary":"#57263C","primaryHover":"#431C2E","accent":"#A8862F","text":"#1E1A1D","textMuted":"#6B5F66",
              "tint":"#F5F0F2","line":"#E4DDE1","headingFont":"ANTON","textFont":"INTER","headingCaps":true,
              "radiusSmall":4,"radiusLarge":8}}
    """

private let brand = try! JSONDecoder().decode(Club.self, from: Data(sdgClub.utf8)).brand

@Test func lightModeTakesTheBrandAsItIs() {
    let light = Palette(brand, dark: false)
    #expect(light.accent == brand.primary)
    #expect(light.surface == brand.tint)
    #expect(light.onAccent == .white)
}

/// Expected values come from club-client's `ThemeService.branded` for the same brand.
@Test func darkModeMatchesTheWeb() {
    let dark = Palette(brand, dark: true)
    #expect(hex(dark.accent) == "#bf6c91")
    #expect(hex(dark.accentHover) == "#c77e9e")
    #expect(hex(dark.highlight) == "#a8862f")
    #expect(hex(dark.onAccent) == "#1e1a1d")
    #expect(dark.text == nil && dark.surface == nil)
}

@Test func unknownFontFallsBackToSystem() throws {
    let font = try JSONDecoder().decode([Club.Font].self, from: Data(#"["ANTON","COMIC"]"#.utf8))
    #expect(font == [.anton, .system])
}

private func hex(_ c: RGB) -> String {
    "#" + [c.red, c.green, c.blue].map { String(format: "%02x", Int(($0 * 255).rounded())) }.joined()
}
