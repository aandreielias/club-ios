import ClubKit
import SwiftUI

@main
struct ClubMain: App {
    @State private var model = AppModel(api: ApiClient(baseURL: ClubMain.apiURL))

    var body: some Scene {
        WindowGroup { RootView(model: model) }
    }

    /// Set per build in project.yml (`CLUB_API_URL`).
    private static let apiURL: URL = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "ClubAPIURL") as? String, let url = URL(string: value) else {
            fatalError("ClubAPIURL missing in Info.plist")
        }
        return url
    }()
}
