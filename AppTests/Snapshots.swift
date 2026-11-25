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
    @Test func login() throws {
        try snap("login", LoginView(club: .sample, logoURL: nil, signIn: { _, _ in }, resetPassword: { _ in }))
    }

    @Test func forgotPassword() throws {
        try snap("forgot-password", ForgotPasswordView(email: "anna@example.at") { _ in })
    }

    @Test func locked() throws {
        try snap("locked", LockedView(club: .sample, logoURL: nil, unlock: {}, signOut: {}))
    }

    @Test func onboarding() throws {
        try snap("onboarding", OnboardingView(me: .sample, save: { _ in }, signOut: {}))
    }

    @Test func start() throws {
        try snap("start", StartView(club: .sample, logoURL: nil, me: .sample, signOut: {}))
    }

    @Test func loadFailed() throws {
        try snap("load-failed", LoadFailedView {})
    }

    private func snap(_ name: String, _ view: some View) throws {
        let dir = URL(fileURLWithPath: ProcessInfo.processInfo.environment["SNAPSHOT_DIR"]!)
        let scene = try #require(UIApplication.shared.connectedScenes.first as? UIWindowScene)
        for (style, suffix) in [(UIUserInterfaceStyle.light, "light"), (.dark, "dark")] {
            let window = UIWindow(windowScene: scene)
            window.frame = scene.screen.bounds
            window.overrideUserInterfaceStyle = style
            window.rootViewController = UIHostingController(rootView: view.tint(Color(Club.sample.brand.primary)))
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

extension Me {
    static let sample: Me = try! JSONDecoder().decode(Me.self, from: Data("""
        {"member":{"id":"m1","firstName":"Anna"},"missing":["birthDate"]}
        """.utf8))
}
