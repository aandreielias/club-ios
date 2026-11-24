import ClubKit
import SwiftUI
import Testing
import UIKit
@testable import ClubApp

/// Renders screens in light and dark mode as PNGs into `SNAPSHOT_DIR` (CI uploads them as an artifact).
/// Nothing is compared: they are there to look at the style without a Mac.
@MainActor
@Suite(.enabled(if: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] != nil))
struct Snapshots {
    @Test func start() throws {
        try snap("start", StartView(club: .sample, logoURL: nil).tint(Color(Club.sample.brand.primary)))
    }

    @Test func loadFailed() throws {
        try snap("load-failed", LoadFailedView {}.tint(Color(Club.sample.brand.primary)))
    }

    private func snap(_ name: String, _ view: some View) throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]!)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for (style, suffix) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
            let window = UIWindow(windowScene: scene)
            window.frame = scene.screen.bounds
            window.overrideUserInterfaceStyle = style
            window.rootViewController = UIHostingController(rootView: view)
            window.isHidden = false
            window.layoutIfNeeded()
            let image = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
                _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
            }
            try #require(image.pngData()).write(to: dir.appending(path: "\(name)-\(suffix).png"))
            window.isHidden = true
        }
    }
}

extension Club {
    static let sample: Club = try! JSONDecoder().decode(Club.self, from: Data("""
        {"name":"SDG Vienna","brand":{"primary":"#5E6AD2","headingCaps":true},"assets":{"logo":null}}
        """.utf8))
}
