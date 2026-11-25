import ClubKit
import Foundation
import Observation

/// App start and login: the club's facts and look first, then the member's session.
@MainActor @Observable
final class AppModel {
    enum State {
        case loading
        case failed
        case signedOut
        case locked
        case onboarding(Me)
        case ready(Me)
    }

    private(set) var state = State.loading
    /// Set once loaded; every state after `loading` and `failed` has it.
    private(set) var club: Club?
    let api: ApiClient
    private let auth: Auth

    init(api: ApiClient, auth: Auth) {
        self.api = api
        self.auth = auth
    }

    func load() async {
        state = .loading
        do {
            club = try await api.club()
            if await auth.email == nil {
                state = .signedOut
            } else if Biometrics.available {
                state = .locked
            } else {
                try await enter()
            }
        } catch {
            state = .failed
        }
    }

    func signIn(email: String, password: String) async throws {
        try await auth.signIn(email: email, password: password)
        try await enter()
    }

    func resetPassword(email: String) async throws {
        try await auth.resetPassword(email: email)
    }

    func unlock() async {
        guard await Biometrics.unlock() else { return }
        do { try await enter() } catch { state = .failed }
    }

    /// Back behind Face ID when the app goes to the background.
    func lock() {
        switch state {
        case .ready, .onboarding: if Biometrics.available { state = .locked }
        default: break
        }
    }

    func signOut() async {
        await auth.signOut()
        state = .signedOut
    }

    func saveBirthDate(_ date: Date, of me: Me) async throws {
        let day = date.formatted(Date.ISO8601FormatStyle(timeZone: .current).year().month().day())
        try await api.updateProfile(of: me.member.id, ProfileBody(birthDate: day))
        try await enter()
    }

    private func enter() async throws {
        do {
            let me = try await api.me()
            state = me.missing.isEmpty ? .ready(me) : .onboarding(me)
        } catch let problem as ProblemError where problem.status == 401 {
            await signOut()
        }
    }
}
