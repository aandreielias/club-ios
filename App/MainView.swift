import ClubKit
import SwiftUI

/// Signed in: one tab per area.
struct MainView: View {
    let club: Club
    let logoURL: URL?
    let me: Me
    let api: ApiClient
    let signOut: () -> Void
    @State private var inbox: InboxModel

    init(club: Club, logoURL: URL?, me: Me, api: ApiClient, signOut: @escaping () -> Void) {
        self.club = club
        self.logoURL = logoURL
        self.me = me
        self.api = api
        self.signOut = signOut
        _inbox = State(initialValue: InboxModel(api: api))
    }

    var body: some View {
        TabView {
            StartView(club: club, logoURL: logoURL, me: me)
                .tabItem { Label("Start", systemImage: "house") }
            CalendarView(model: CalendarModel(api: api, me: me, calendar: .club(club)))
                .tabItem { Label("Kalender", systemImage: "calendar") }
            InboxView(model: inbox, me: me, calendar: .club(club))
                .tabItem { Label("Mitteilungen", systemImage: "bell") }
                .badge(inbox.unread)
            MoreView(api: api, me: me, calendar: .club(club), signOut: signOut)
                .tabItem { Label("Mehr", systemImage: "ellipsis") }
        }
        // shortcut: the inbox loads at start and on pull-to-refresh; live updates (/ws) and push follow.
        .task { await inbox.load() }
    }
}
