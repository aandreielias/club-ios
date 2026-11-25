import ClubKit
import SwiftUI

struct RootView: View {
    let model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .failed:
                LoadFailedView { Task { await model.load() } }
            default:
                if let club = model.club {
                    signedIn(club).tint(Color(club.brand.primary))
                }
            }
        }
        .task { await model.load() }
        .onChange(of: scenePhase) { if scenePhase == .background { model.lock() } }
    }

    @ViewBuilder
    private func signedIn(_ club: Club) -> some View {
        let logoURL = club.assets.logo.map(model.api.url)
        let signOut: () -> Void = { Task { await model.signOut() } }
        switch model.state {
        case .signedOut:
            LoginView(club: club, logoURL: logoURL, signIn: model.signIn, resetPassword: model.resetPassword)
        case .locked:
            LockedView(club: club, logoURL: logoURL, unlock: model.unlock, signOut: signOut)
        case .onboarding(let me):
            OnboardingView(me: me, save: { try await model.saveBirthDate($0, of: me) }, signOut: signOut)
        case .ready(let me):
            StartView(club: club, logoURL: logoURL, me: me, signOut: signOut)
        case .loading, .failed:
            EmptyView()
        }
    }
}
