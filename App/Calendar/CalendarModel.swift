import ClubKit
import Foundation
import Observation

/// One month of the calendar with the member's answer marks and the answers still open.
@MainActor @Observable
final class CalendarModel {
    let api: ApiClient
    let me: Me
    let calendar: Calendar

    var month: Month
    /// Nil until loaded.
    var items: [CalendarItem]?
    var marks: [String: Answer] = [:]
    var openAnswers: [OpenAnswer] = []
    var types: [String: AppointmentType] = [:]
    var failed = false

    init(api: ApiClient, me: Me, calendar: Calendar, now: Date = Date()) {
        self.api = api
        self.me = me
        self.calendar = calendar
        month = Month(containing: now, calendar: calendar)
    }

    func show(_ month: Month) async {
        self.month = month
        items = nil
        await load()
    }

    func load() async {
        let shown = month
        let (from, to) = shown.range
        let (api, needTypes) = (api, types.isEmpty)
        do {
            async let items = api.calendarItems(from: from, to: to)
            // An answer endpoint failing only leaves the marks and the open answers out, like the web.
            async let marks = try? api.myAnswers(from: from, to: to)
            async let open = try? api.openAnswers()
            async let types = needTypes ? (try? api.appointmentTypes()) : nil
            let loaded = try await items
            guard shown == month else { return }  // another month was picked meanwhile
            self.items = loaded
            self.marks = await marks ?? [:]
            openAnswers = await open ?? []
            if let list = await types { self.types = Dictionary(list.map { ($0.key, $0) }) { first, _ in first } }
            failed = false
        } catch {
            failed = true
        }
    }

    /// The colour of an entry: its appointment type's, else its category's.
    // shortcut: meetings show their category colour, not their meeting type's; load /meetings/types with the meetings area.
    func hue(_ item: CalendarItem) -> String {
        item.category == .appointment ? (item.detail.flatMap { types[$0]?.hue } ?? item.category.hue) : item.category.hue
    }
}
