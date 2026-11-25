import ClubKit
import SwiftUI

@main
struct ClubMain: App {
    @State private var model: AppModel

    init() {
        let auth = Auth(url: Self.url("ClubSupabaseURL"), publishableKey: Self.setting("ClubSupabaseKey"), storage: KeychainStorage())
        _model = State(initialValue: AppModel(api: ApiClient(baseURL: Self.url("ClubAPIURL"), token: { try await auth.token() }), auth: auth))
    }

    var body: some Scene {
        WindowGroup { RootView(model: model) }
    }

    /// Set per build in project.yml (`CLUB_API_URL`, `CLUB_SUPABASE_URL`, `CLUB_SUPABASE_KEY`).
    private static func setting(_ key: String) -> String {
        Bundle.main.object(forInfoDictionaryKey: key) as? String ?? ""
    }

    private static func url(_ key: String) -> URL {
        guard let url = URL(string: setting(key)), url.scheme != nil else { fatalError("\(key) missing in Info.plist") }
        return url
    }
}
