import ClubKit
import SwiftUI

/// Signed in. Placeholder until the start page sections come.
struct StartView: View {
    let club: Club
    let logoURL: URL?
    let me: Me
    let signOut: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                ClubHeader(club: club, logoURL: logoURL)
                Text("Hallo, \(me.member.firstName)")
                    .font(.title2)
            }
            .toolbar {
                Button("Abmelden", action: signOut)
            }
        }
    }
}
