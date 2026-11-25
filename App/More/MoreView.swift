import ClubKit
import SwiftUI

/// Everything without a tab of its own; for now the account.
struct MoreView: View {
    let me: Me
    let signOut: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Konto") {
                    Button("Abmelden", role: .destructive, action: signOut)
                }
            }
            .brandSurface()
            .navigationTitle("Mehr")
        }
    }
}
