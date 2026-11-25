import ClubKit
import SwiftUI

/// A stored session waits for Face ID / Touch ID (or the device passcode).
struct LockedView: View {
    let club: Club
    let logoURL: URL?
    let unlock: @MainActor () async -> Void
    let signOut: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            ClubHeader(club: club, logoURL: logoURL)
            Button {
                Task { await unlock() }
            } label: {
                Label("Entsperren", systemImage: "faceid")
            }
            .buttonStyle(.borderedProminent)
            Button("Abmelden", action: signOut)
        }
        .task { await unlock() }
    }
}
