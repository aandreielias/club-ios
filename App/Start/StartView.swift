import ClubKit
import SwiftUI

/// The start tab. Placeholder until the start page sections come.
struct StartView: View {
    let club: Club
    let logoURL: URL?
    let me: Me
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ClubHeader(club: club, logoURL: logoURL)
                Text("Hallo, \(me.member.firstName)")
                    .font(theme.font(.title2, weight: .semibold))
            }
        }
    }
}
