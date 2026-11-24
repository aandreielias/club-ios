import ClubKit
import SwiftUI

struct RootView: View {
    let model: AppModel

    var body: some View {
        Group {
            switch model.state {
            case .loading:
                ProgressView()
            case .failed:
                LoadFailedView { Task { await model.load() } }
            case .ready(let club):
                StartView(club: club, logoURL: club.assets.logo.map(model.api.url))
                    .tint(Color(club.brand.primary))
            }
        }
        .task { await model.load() }
    }
}
