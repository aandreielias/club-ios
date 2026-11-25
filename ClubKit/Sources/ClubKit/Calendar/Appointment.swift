import Foundation

/// One appointment (`GET /api/v1/appointments/{id}`).
public struct Appointment: Decodable, Sendable, Identifiable {
    public let id: String
    /// Null = club-wide.
    public let teamId: String?
    /// Key of a club-defined `AppointmentType`.
    public let type: String
    public let title: String
    public let description: String?
    public let location: String?
    public let startsAt: Date
    public let endsAt: Date
    public let cancelled: Bool
    public let cancelReason: String?
    /// Car pools offered.
    public let rides: Bool
}

/// A club-defined appointment type with its answer rules (`GET /api/v1/calendar/types`).
public struct AppointmentType: Decodable, Sendable {
    public let key: String
    public let label: String
    public let hue: String
    /// Answers close that long before the start.
    public let answerDeadlineHours: Int
    public let allowMaybe: Bool
    public let reasonOnNo: Bool
    /// TEAM, CLUB or NONE (no answers at all).
    public let expectAnswers: String
}

/// Who said what (`GET /api/v1/appointments/{id}/attendance`).
public struct Attendance: Decodable, Sendable {
    public let yes: Int
    public let no: Int
    public let maybe: Int
    public let open: Int
    public let entries: [Entry]

    public struct Entry: Decodable, Sendable, Identifiable {
        public let memberId: String
        public let name: String
        /// Null = no answer yet.
        public let status: Answer?
        /// Only for who may see reasons.
        public let reason: String?
        /// An absence covers the day.
        public let absent: Bool
        /// The appointment moved after a yes or maybe; answering again confirms.
        public let unconfirmed: Bool

        public var id: String { memberId }
    }
}

public enum Answer: String, Codable, Sendable, CaseIterable {
    case yes = "YES", no = "NO", maybe = "MAYBE"
}

/// `PUT /api/v1/appointments/{id}/attendance`.
public struct AnswerBody: Encodable, Sendable {
    public let memberId: String
    public let status: Answer
    public let reason: String?

    public init(memberId: String, status: Answer, reason: String?) {
        self.memberId = memberId
        self.status = status
        self.reason = reason
    }
}

/// An upcoming appointment still waiting for the member's or a ward's answer (`GET /api/v1/me/open-answers`).
public struct OpenAnswer: Decodable, Sendable, Identifiable {
    public let appointmentId: String
    public let title: String
    public let startsAt: Date
    public let memberId: String
    public let name: String

    public var id: String { "\(appointmentId)/\(memberId)" }
}

/// Own and wards' answers in a range, to mark the calendar (`GET /api/v1/me/answers`).
public struct MyAnswer: Decodable, Sendable {
    public let appointmentId: String
    public let status: Answer
}

struct Items<T: Decodable>: Decodable { let items: [T] }

extension ApiClient {
    public func appointment(_ id: String) async throws -> Appointment {
        try await get("/api/v1/appointments/\(id)")
    }

    public func appointmentTypes() async throws -> [AppointmentType] {
        let answer: Items<AppointmentType> = try await get("/api/v1/calendar/types")
        return answer.items
    }

    public func attendance(of appointmentId: String) async throws -> Attendance {
        try await get("/api/v1/appointments/\(appointmentId)/attendance")
    }

    public func answer(_ appointmentId: String, _ body: AnswerBody) async throws {
        try await put("/api/v1/appointments/\(appointmentId)/attendance", body)
    }

    public func openAnswers() async throws -> [OpenAnswer] {
        let answer: Items<OpenAnswer> = try await get("/api/v1/me/open-answers")
        return answer.items
    }

    /// One mark per appointment: a yes of anyone (self or a ward) wins, else the first answer (like the web's marks).
    public func myAnswers(from: Date, to: Date) async throws -> [String: Answer] {
        let answer: Items<MyAnswer> = try await get("/api/v1/me/answers", query: ["from": Self.instant(from), "to": Self.instant(to)])
        var marks: [String: Answer] = [:]
        for a in answer.items where marks[a.appointmentId] == nil || a.status == .yes { marks[a.appointmentId] = a.status }
        return marks
    }
}
