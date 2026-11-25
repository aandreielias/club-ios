import Foundation

/// Anything with a date the member sees, from every module (`GET /api/v1/calendar/items`).
public struct CalendarItem: Decodable, Sendable, Identifiable, Equatable {
    /// What it opens: appointment, holiday, task, meeting, tournament, absence, member.
    public let kind: String
    public let id: String
    public let title: String
    public let start: Date
    /// All-day items end at the start of the day after their last day; points in time have none.
    public let end: Date?
    public let allDay: Bool
    public let category: Category
    public let teamId: String?
    /// Cancelled appointments, done tasks.
    public let inactive: Bool
    /// Per kind: the appointment or meeting type key, an absence's reason.
    public let detail: String?

    /// Filter and colour groups (`platform.CalendarItems.Category`).
    public enum Category: String, Decodable, Sendable {
        case appointment = "APPOINTMENT", task = "TASK", followUp = "FOLLOW_UP", meeting = "MEETING", tournament = "TOURNAMENT"
        case absence = "ABSENCE", birthday = "BIRTHDAY", holiday = "HOLIDAY"

        /// Its colour unless the item's type has its own (club-client `lib/calendar/categories.ts`).
        public var hue: String {
            switch self {
            case .appointment: "blue"
            case .task: "orange"
            case .followUp: "brown"
            case .meeting: "purple"
            case .tournament: "yellow"
            case .birthday: "green"
            case .absence, .holiday: "gray"
            }
        }

        /// A category added to the server later shows like an appointment instead of failing the whole calendar.
        public init(from decoder: Decoder) throws {
            self = Category(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .appointment
        }
    }

    /// Whether it falls on the day starting at `dayStart` (the next day starts at `dayEnd`).
    public func overlaps(_ dayStart: Date, _ dayEnd: Date) -> Bool {
        guard let end, end > start else { return start >= dayStart && start < dayEnd }
        return start < dayEnd && end > dayStart
    }
}

extension ApiClient {
    /// Everything overlapping [from, to) (at most 366 days), sorted by start.
    public func calendarItems(from: Date, to: Date) async throws -> [CalendarItem] {
        let answer: Items<CalendarItem> = try await get("/api/v1/calendar/items", query: ["from": Self.instant(from), "to": Self.instant(to)])
        return answer.items.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }
}
