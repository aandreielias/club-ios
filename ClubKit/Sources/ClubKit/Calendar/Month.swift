import Foundation

/// The month grid in the club's calendar (time zone, first weekday from the locale): whole weeks around the month.
public struct Month: Equatable, Sendable {
    public let calendar: Calendar
    /// Start of the month's first day.
    public let start: Date

    public init(containing date: Date, calendar: Calendar) {
        self.calendar = calendar
        start = calendar.dateInterval(of: .month, for: date)!.start
    }

    public func adding(_ months: Int) -> Month {
        Month(containing: calendar.date(byAdding: .month, value: months, to: start)!, calendar: calendar)
    }

    /// Start of each day shown, in weeks of seven (from the first weekday of the month's first week).
    public var days: [Date] {
        let first = calendar.dateInterval(of: .weekOfMonth, for: start)!.start
        let last = calendar.date(byAdding: .day, value: -1, to: calendar.date(byAdding: .month, value: 1, to: start)!)!
        let end = calendar.dateInterval(of: .weekOfMonth, for: last)!.end
        return Array(sequence(first: first) { calendar.date(byAdding: .day, value: 1, to: $0)! }.prefix { $0 < end })
    }

    /// The range to load: the whole grid.
    public var range: (from: Date, to: Date) {
        let days = days
        return (days.first!, calendar.date(byAdding: .day, value: 1, to: days.last!)!)
    }

    public func contains(_ day: Date) -> Bool {
        calendar.isDate(day, equalTo: start, toGranularity: .month)
    }

    /// The items falling on `day` (a day start).
    public func items(_ items: [CalendarItem], on day: Date) -> [CalendarItem] {
        let next = calendar.date(byAdding: .day, value: 1, to: day)!
        return items.filter { $0.overlaps(day, next) }
    }
}

extension Calendar {
    /// Gregorian in the club's zone and locale (Monday first in de-AT).
    public static func club(_ club: Club) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: club.timeZone) ?? .current
        calendar.locale = Locale(identifier: club.locale)
        return calendar
    }
}

extension Date.FormatStyle {
    /// The style in the club's zone and locale, whatever the phone is set to.
    public func club(_ calendar: Calendar) -> Self {
        var style = self
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        style.locale = calendar.locale ?? .current
        return style
    }
}
