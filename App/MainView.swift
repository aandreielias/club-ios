import ClubKit
import SwiftUI

/// Signed in: one tab per area.
struct MainView: View {
    let club: Club
    let logoURL: URL?
    let me: Me
    let api: ApiClient
    let signOut: () -> Void

    var body: some View {
        TabView {
            StartView(club: club, logoURL: logoURL, me: me)
                .tabItem { Label("Start", systemImage: "house") }
            CalendarView(model: CalendarModel(api: api, me: me, calendar: .club(club)))
                .tabItem { Label("Kalender", systemImage: "calendar") }
            MoreView(me: me, signOut: signOut)
                .tabItem { Label("Mehr", systemImage: "ellipsis") }
        }
    }
}
