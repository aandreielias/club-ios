import ClubKit
import Foundation
import Observation

/// Car pools of one appointment and the changes the member makes to them.
@MainActor @Observable
final class RidesModel {
    let api: ApiClient
    let me: Me
    let appointmentId: String

    /// Nil until loaded.
    var rides: [Ride]?
    /// The club's "most seats per car" (Kalender-Regeln).
    var maxSeats = 8
    var busy = false
    var error: String?
    /// One Idempotency-Key per offer, so a retried request does not offer a second car.
    private var offerKey = UUID().uuidString

    init(api: ApiClient, me: Me, appointmentId: String) {
        self.api = api
        self.me = me
        self.appointmentId = appointmentId
    }

    var driving: Bool { Rides.driving(rides ?? [], me: me) }

    func name(_ memberId: String) -> String {
        memberId == me.member.id ? String(localized: "Ich") : me.wardNames[memberId] ?? memberId
    }

    func load() async {
        let (api, id) = (api, appointmentId)
        async let settings = try? api.calendarSettings()
        rides = (try? await api.rides(of: id)) ?? rides ?? []
        if let max = await settings?.maxRideSeats { maxSeats = max }
    }

    /// True when the offer went through.
    func offer(seats: Int, note: String) async -> Bool {
        let text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let (api, id, key) = (api, appointmentId, offerKey)
        let ok = await run { try await api.offerRide(id, RideBody(seats: seats, note: text.isEmpty ? nil : text), key: key) }
        if ok { offerKey = UUID().uuidString }
        return ok
    }

    func join(_ ride: Ride, _ memberId: String) async {
        let api = api, own = memberId == me.member.id
        _ = await run { try await api.joinRide(ride.id, memberId: own ? nil : memberId) }
    }

    func leave(_ ride: Ride, _ memberId: String) async {
        let api = api
        _ = await run { try await api.leaveRide(ride.id, memberId: memberId) }
    }

    func cancel(_ ride: Ride) async {
        let api = api
        _ = await run { try await api.cancelRide(ride.id) }
    }

    private func run(_ call: @escaping @Sendable () async throws -> Void) async -> Bool {
        busy = true
        error = nil
        defer { busy = false }
        do {
            try await call()
            await load()
            return true
        } catch {
            self.error = ErrorTexts.app.text(error)
            return false
        }
    }
}
