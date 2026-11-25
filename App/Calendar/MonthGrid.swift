import ClubKit
import SwiftUI

/// Weeks of the month; each day shows up to three coloured dots for its entries. Tapping picks the day.
struct MonthGrid: View {
    let model: CalendarModel
    @Binding var selected: Date?
    @Environment(\.theme) private var theme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 0), count: 7)

    var body: some View {
        let cal = model.calendar
        let today = cal.startOfDay(for: Date())
        let chosen = selected ?? (model.month.contains(today) ? today : model.month.start)
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(weekdays.indices, id: \.self) { index in  // German short names repeat (M, D, M, D …)
                Text(weekdays[index]).font(theme.font(.caption, weight: .semibold)).foregroundStyle(theme.textMuted)
            }
            ForEach(model.month.days, id: \.self) { day in
                let entries = model.items.map { model.month.items($0, on: day) } ?? []
                Button { selected = day } label: {
                    VStack(spacing: 3) {
                        Text(day.formatted(.dateTime.day().club(cal)))
                            .font(theme.font(.callout, weight: day == today ? .semibold : .regular))
                            .foregroundStyle(day == today ? theme.accent : model.month.contains(day) ? theme.text : theme.textMuted.opacity(0.5))
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(day == chosen ? theme.accent.opacity(0.15) : .clear))
                        HStack(spacing: 2) {
                            ForEach(Array(entries.prefix(3).enumerated()), id: \.offset) { _, item in
                                Circle().fill(Color(hue: model.hue(item))).frame(width: 5, height: 5)
                            }
                        }
                        .frame(height: 5)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(day.formatted(.dateTime.weekday(.wide).day().month(.wide).club(cal)))
                .accessibilityValue(entries.isEmpty ? "" : String(localized: "\(entries.count) Einträge"))
                .accessibilityAddTraits(day == chosen ? .isSelected : [])
            }
        }
        .padding(.vertical, 8)
    }

    /// Short weekday names from the club's first weekday (Monday in de-AT).
    private var weekdays: [String] {
        let cal = model.calendar
        let names = cal.veryShortStandaloneWeekdaySymbols
        return (0..<7).map { names[(cal.firstWeekday - 1 + $0) % 7] }
    }
}
