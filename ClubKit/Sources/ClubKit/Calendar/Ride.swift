import Foundation

/// A car pool of an appointment: the driver offers seats, members take one for themselves or a ward.
public struct Ride: Decodable, Sendable, Identifiable {
    public let id: String
    public let driverId: String
    public let driverName: String
    public let seats: Int
    public let note: String?
    public let passengers: [Passenger]

    public struct Passenger: Decodable, Sendable, Identifiable {
        public let memberId: String
        public let name: String

        public var id: String { memberId }
    }

    public var free: Int { seats - passengers.count }

    public func has(_ memberId: String) -> Bool { passengers.contains { $0.memberId == memberId } }
}

/// `POST /api/v1/appointments/{id}/rides`.
public struct RideBody: Encodable, Sendable {
    public let seats: Int
    public let note: String?

    public init(seats: Int, note: String?) {
        self.seats = seats
        self.note = note
    }
}

/// `PUT /api/v1/rides/{id}/passengers`; no `memberId` = the member themselves.
public struct PassengerBody: Encodable, Sendable {
    public let memberId: String?
}

/// The club's calendar rules the app needs (`GET /api/v1/calendar/settings`).
public struct CalendarSettings: Decodable, Sendable {
    public let maxRideSeats: Int
}

/// Who may do what in a car pool, ported from club-client `RidesPanel` (the server decides again).
/// shortcut: coaches and board may also cancel others' rides and remove anyone; the app leaves that to the web until the coach tools (phase 2).
public enum Rides {
    /// The member drives a car of their own.
    public static func driving(_ rides: [Ride], me: Me) -> Bool {
        rides.contains { $0.driverId == me.member.id }
    }

    /// The member and wards who could still get a seat in this car.
    public static func riders(_ ride: Ride, me: Me) -> [String] {
        ([me.member.id] + me.wardIds.sorted()).filter { $0 != ride.driverId && !ride.has($0) }
    }

    /// The passenger themselves, their guardian, or the driver.
    public static func mayRemove(_ ride: Ride, _ memberId: String, me: Me) -> Bool {
        memberId == me.member.id || ride.driverId == me.member.id || me.wardIds.contains(memberId)
    }
}

extension ApiClient {
    public func rides(of appointmentId: String) async throws -> [Ride] {
        let answer: Items<Ride> = try await get("/api/v1/appointments/\(appointmentId)/rides")
        return answer.items
    }

    public func offerRide(_ appointmentId: String, _ body: RideBody, key: String) async throws {
        let _: Ride = try await post("/api/v1/appointments/\(appointmentId)/rides", body, key: key)
    }

    public func cancelRide(_ rideId: String) async throws {
        try await delete("/api/v1/rides/\(rideId)")
    }

    /// `memberId` nil = the member themselves.
    public func joinRide(_ rideId: String, memberId: String?) async throws {
        try await put("/api/v1/rides/\(rideId)/passengers", PassengerBody(memberId: memberId))
    }

    public func leaveRide(_ rideId: String, memberId: String) async throws {
        try await delete("/api/v1/rides/\(rideId)/passengers/\(memberId)")
    }

    public func calendarSettings() async throws -> CalendarSettings {
        try await get("/api/v1/calendar/settings")
    }
}
