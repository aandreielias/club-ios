import ClubKit
import Observation

/// App start: loads the club's facts and look before anything else is shown.
@MainActor @Observable
final class AppModel {
    enum State {
        case loading
        case failed
        case ready(Club)
    }

    private(set) var state = State.loading
    let api: ApiClient

    init(api: ApiClient) {
        self.api = api
    }

    func load() async {
        state = .loading
        do {
            state = .ready(try await api.club())
        } catch {
            state = .failed
        }
    }
}
