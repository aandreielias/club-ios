import Foundation

/// Plain dates (`yyyy-MM-dd`, e.g. absences) as days of the club's calendar.
extension Calendar {
    /// Midnight of that day in the calendar's time zone.
    public func day(_ text: String) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    public func dayText(_ date: Date) -> String {
        let c = dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }
}
