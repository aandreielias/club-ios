import ClubKit
import SwiftUI

/// Absences of the member and their wards: appointments on those days count as "Nein" until answered.
struct AbsencesView: View {
    @State var model: AbsencesModel
    @State private var adding = false
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            Section {
                ForEach(model.absences ?? []) { row($0) }
                    .onDelete { offsets in
                        let doomed = offsets.compactMap { model.absences?[$0] }
                        Task { for absence in doomed { await model.delete(absence) } }
                    }
            } footer: {
                if let error = model.error {
                    Text(error).foregroundStyle(.red)
                } else {
                    Text("Termine an diesen Tagen zählen als „Nein“, bis du anders antwortest.")
                }
            }
        }
        .brandSurface()
        .overlay {
            if model.failed {
                LoadFailedView { Task { await model.load() } }
            } else if model.absences == nil {
                ProgressView()
            } else if model.absences?.isEmpty == true {
                ContentUnavailableView("Keine kommenden Abwesenheiten.", systemImage: "calendar.badge.minus")
            }
        }
        .refreshable { await model.load() }
        .task { if model.absences == nil { await model.load() } }
        .navigationTitle("Abwesenheiten")
        .toolbar {
            Button { adding = true } label: { Image(systemName: "plus") }
                .accessibilityLabel("Abwesenheit eintragen")
        }
        .sheet(isPresented: $adding) { AbsenceFormView(model: model) }
    }

    private func row(_ absence: Absence) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(range(absence))
            if !model.me.wardIds.isEmpty || absence.memberId != model.me.member.id {
                Text(model.name(absence.memberId)).font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
            }
            if let reason = absence.reason, !reason.isEmpty {
                Text(reason).font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
            }
        }
    }

    private func range(_ absence: Absence) -> String {
        let cal = model.calendar
        let style = Date.FormatStyle.dateTime.weekday().day().month().year().club(cal)
        guard let from = cal.day(absence.from), let to = cal.day(absence.to) else { return "\(absence.from) – \(absence.to)" }
        return from == to ? from.formatted(style) : "\(from.formatted(style)) – \(to.formatted(style))"
    }
}

/// New absence: who, from, to, an optional reason.
private struct AbsenceFormView: View {
    let model: AbsencesModel
    @State private var memberId: String
    @State private var from: Date
    @State private var to: Date
    @State private var reason = ""
    @State private var busy = false
    @State private var error: String?
    /// One Idempotency-Key per form, so a retry does not enter the absence twice.
    @State private var key = UUID().uuidString
    @Environment(\.dismiss) private var dismiss

    /// club-client `AbsenceForm`: at most a year, reason ≤ 300.
    private let maxDays = 366
    private let reasonMaxLength = 300

    init(model: AbsencesModel) {
        self.model = model
        let today = model.calendar.startOfDay(for: Date())
        _memberId = State(initialValue: model.me.member.id)
        _from = State(initialValue: today)
        _to = State(initialValue: today)
    }

    var body: some View {
        NavigationStack {
            Form {
                if !model.me.wardIds.isEmpty {
                    Picker("Für", selection: $memberId) {
                        Text("Mich").tag(model.me.member.id)
                        ForEach(model.me.wardIds.sorted(), id: \.self) { Text(model.name($0)).tag($0) }
                    }
                }
                DatePicker("Von", selection: $from, in: today..., displayedComponents: .date)
                DatePicker("Bis", selection: $to, in: from...last, displayedComponents: .date)
                Section {
                    TextField("Grund (optional)", text: $reason, prompt: Text("z. B. Urlaub, Verletzung"), axis: .vertical)
                        .onChange(of: reason) { if reason.count > reasonMaxLength { reason = String(reason.prefix(reasonMaxLength)) } }
                } footer: {
                    if let error {
                        Text(error).foregroundStyle(.red)
                    } else {
                        Text("Sehen nur Trainer:innen der Teams, Vorstand und Admins.")
                    }
                }
            }
            .onChange(of: from) { to = min(max(to, from), last) }
            .navigationTitle("Abwesenheit eintragen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Abbrechen") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Eintragen", action: save).disabled(busy) }
            }
        }
    }

    private var today: Date { model.calendar.startOfDay(for: Date()) }
    private var last: Date { model.calendar.date(byAdding: .day, value: maxDays - 1, to: from) ?? from }

    private func save() {
        let cal = model.calendar
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let body = AbsenceBody(
            memberId: memberId == model.me.member.id ? nil : memberId,
            from: cal.dayText(from), to: cal.dayText(to), reason: text.isEmpty ? nil : text)
        busy = true
        error = nil
        Task {
            do {
                try await model.add(body, key: key)
                dismiss()
            } catch {
                self.error = ErrorTexts.app.text(error)
            }
            busy = false
        }
    }
}
