import ClubKit
import SwiftUI

/// Everything without a tab of its own: absences, the account.
struct MoreView: View {
    let api: ApiClient
    let me: Me
    let calendar: Calendar
    let signOut: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("Kalender") {
                    NavigationLink("Abwesenheiten") {
                        AbsencesView(model: AbsencesModel(api: api, me: me, calendar: calendar))
                    }
                }
                Section("Konto") {
                    Button("Abmelden", role: .destructive, action: signOut)
                }
            }
            .brandSurface()
            .navigationTitle("Mehr")
        }
    }
}
