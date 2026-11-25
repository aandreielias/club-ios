import ClubKit
import SwiftUI

/// The calendar tab: month grid with the chosen day's entries, or the month as a list; open answers on top.
struct CalendarView: View {
    @State private var model: CalendarModel
    @State private var mode = Mode.month
    @State private var selected: Date?
    @Environment(\.theme) private var theme

    enum Mode { case month, list }

    init(model: CalendarModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            List {
                if !model.openAnswers.isEmpty { openAnswers }
                if mode == .month {
                    Section { MonthGrid(model: model, selected: $selected).listRowInsets(EdgeInsets()) }
                    dayEntries
                } else {
                    monthList
                }
            }
            .brandSurface()
            .overlay { if model.items == nil && !model.failed { ProgressView() } }
            .overlay { if model.failed { LoadFailedView { Task { await model.load() } } } }
            .refreshable { await model.load() }
            .task { if model.items == nil { await model.load() } }
            .navigationTitle(model.month.start.formatted(.dateTime.month(.abbreviated).year().club(model.calendar)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .navigationDestination(for: AppointmentLink.self) { link in
                AppointmentView(model: AppointmentModel(api: model.api, me: model.me, id: link.id, types: model.types)) {
                    await model.load()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            // One button that shows the other view, so the month title keeps its room.
            if mode == .month {
                Button { mode = .list } label: { Image(systemName: "list.bullet") }.accessibilityLabel("Liste")
            } else {
                Button { mode = .month } label: { Image(systemName: "calendar") }.accessibilityLabel("Monat")
            }
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { go(-1) } label: { Image(systemName: "chevron.left") }.accessibilityLabel("Voriger Monat")
            Button("Heute") { go(nil) }
            Button { go(1) } label: { Image(systemName: "chevron.right") }.accessibilityLabel("Nächster Monat")
        }
    }

    private func go(_ months: Int?) {
        let target = months.map { model.month.adding($0) } ?? Month(containing: Date(), calendar: model.calendar)
        selected = months == nil ? model.calendar.startOfDay(for: Date()) : nil
        Task { await model.show(target) }
    }

    private var openAnswers: some View {
        Section("Offene Zusagen") {
            ForEach(model.openAnswers) { open in
                NavigationLink(value: AppointmentLink(id: open.appointmentId)) {
                    VStack(alignment: .leading) {
                        Text(open.title)
                        Text("\(open.startsAt.formatted(.dateTime.weekday().day().month().hour().minute().club(model.calendar))) · \(open.memberId == model.me.member.id ? String(localized: "Ich") : open.name)")
                            .font(theme.font(.subheadline))
                            .foregroundStyle(theme.textMuted)
                    }
                }
            }
        }
    }

    /// The chosen day (today when it is in the month, else the first day).
    private var day: Date {
        if let selected, model.month.contains(selected) { return selected }
        let today = model.calendar.startOfDay(for: Date())
        return model.month.contains(today) ? today : model.month.start
    }

    @ViewBuilder
    private var dayEntries: some View {
        let entries = model.items.map { model.month.items($0, on: day) } ?? []
        Section(day.formatted(.dateTime.weekday(.wide).day().month(.wide).club(model.calendar))) {
            if entries.isEmpty && model.items != nil {
                Text("Keine Einträge").foregroundStyle(theme.textMuted)
            }
            ForEach(entries) { ItemRow(item: $0, model: model, day: day) }
        }
    }

    @ViewBuilder
    private var monthList: some View {
        let items = model.items ?? []
        let days = model.month.days.filter(model.month.contains)
        ForEach(days, id: \.self) { day in
            let entries = model.month.items(items, on: day)
            if !entries.isEmpty {
                Section(day.formatted(.dateTime.weekday(.wide).day().month(.wide).club(model.calendar))) {
                    ForEach(entries) { ItemRow(item: $0, model: model, day: day) }
                }
            }
        }
        if model.items?.isEmpty == true {
            Text("Keine Einträge in diesem Monat").foregroundStyle(theme.textMuted)
        }
    }
}

struct AppointmentLink: Hashable {
    let id: String
}

/// One entry: colour bar, title, time, the answer mark. Appointments open their detail.
private struct ItemRow: View {
    let item: CalendarItem
    let model: CalendarModel
    let day: Date
    @Environment(\.theme) private var theme

    var body: some View {
        // shortcut: appointments and tasks open; meetings, tournaments, absences and birthdays follow with their areas.
        if item.kind == "appointment" {
            NavigationLink(value: AppointmentLink(id: item.id)) { row }
        } else if item.kind == "task" {
            NavigationLink {
                TaskView(model: TaskModel(api: model.api, me: model.me, id: item.id, catalog: TaskCatalog(api: model.api))) {}
            } label: { row }
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 2).fill(Color(hue: model.hue(item))).frame(width: 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .strikethrough(item.inactive)
                    .foregroundStyle(item.inactive ? theme.textMuted : theme.text)
                Text(time).font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
            }
            Spacer()
            if item.kind == "appointment", let mark = model.marks[item.id] { AnswerMark(answer: mark) }
        }
        .accessibilityElement(children: .combine)
    }

    /// "Ganztägig", "18:00–19:30", or only the start for points in time; times outside the day show their date.
    private var time: String {
        if item.allDay { return String(localized: "Ganztägig") }
        let cal = model.calendar
        func format(_ date: Date) -> String {
            let style: Date.FormatStyle = cal.isDate(date, inSameDayAs: day) ? .dateTime.hour().minute() : .dateTime.day().month().hour().minute()
            return date.formatted(style.club(cal))
        }
        guard let end = item.end else { return format(item.start) }
        return "\(format(item.start))–\(format(end))"
    }
}

/// Ja/Nein/Vielleicht as a coloured symbol.
struct AnswerMark: View {
    let answer: Answer?

    var body: some View {
        switch answer {
        case .yes: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("Zusage")
        case .no: Image(systemName: "xmark.circle.fill").foregroundStyle(.red).accessibilityLabel("Absage")
        case .maybe: Image(systemName: "questionmark.circle.fill").foregroundStyle(.yellow).accessibilityLabel("Vielleicht")
        case nil: Image(systemName: "circle.dashed").foregroundStyle(.secondary).accessibilityLabel("Offen")
        }
    }
}
