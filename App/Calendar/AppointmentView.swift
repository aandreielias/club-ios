import ClubKit
import SwiftUI

/// An appointment: facts, the answer for oneself and wards (type rules), and who answered what.
struct AppointmentView: View {
    @State private var model: AppointmentModel
    /// Tells the calendar to refresh its marks and open answers.
    let answered: @MainActor () async -> Void
    @Environment(\.theme) private var theme
    @Environment(\.calendar) private var calendar

    init(model: AppointmentModel, answered: @escaping @MainActor () async -> Void) {
        _model = State(initialValue: model)
        self.answered = answered
    }

    var body: some View {
        List {
            if let appointment = model.appointment {
                facts(appointment)
                let respondents = model.respondents()
                if !respondents.isEmpty {
                    AnswerForm(model: model, respondents: respondents, answered: answered)
                }
                if let attendance = model.attendance, !attendance.entries.isEmpty { people(attendance) }
                if appointment.rides && !appointment.cancelled {
                    RidesSection(model: model.rides, open: appointment.startsAt > Date())
                }
            }
        }
        .brandSurface()
        .overlay { if model.appointment == nil && !model.failed { ProgressView() } }
        .overlay { if model.failed { LoadFailedView { Task { await model.load() } } } }
        .refreshable {
            await model.load()
            if model.appointment?.rides == true { await model.rides.load() }
        }
        .task { if model.appointment == nil { await model.load() } }
        .navigationTitle(model.type?.label ?? String(localized: "Termin"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func facts(_ a: Appointment) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(a.title).heading(.title2).strikethrough(a.cancelled)
                if a.cancelled {
                    Label(a.cancelReason.map { String(localized: "Abgesagt: \($0)") } ?? String(localized: "Abgesagt"), systemImage: "xmark.octagon")
                        .foregroundStyle(.red)
                }
            }
            Label(when(a), systemImage: "clock")
            if let location = a.location, !location.isEmpty { Label(location, systemImage: "mappin.and.ellipse") }
            if let description = a.description, !description.isEmpty { Text(description) }
        }
    }

    /// "Do., 5. Nov., 19:00–20:30", the end with its date when it is on another day.
    private func when(_ a: Appointment) -> String {
        let start = a.startsAt.formatted(.dateTime.weekday().day().month().hour().minute().club(calendar))
        let endStyle: Date.FormatStyle = calendar.isDate(a.endsAt, inSameDayAs: a.startsAt) ? .dateTime.hour().minute() : .dateTime.day().month().hour().minute()
        return "\(start)–\(a.endsAt.formatted(endStyle.club(calendar)))"
    }

    private func people(_ attendance: Attendance) -> some View {
        Section {
            ForEach(attendance.entries) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text(entry.name)
                        if let reason = entry.reason, !reason.isEmpty {
                            Text(reason).font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
                        }
                    }
                    Spacer()
                    if entry.absent {
                        Text("Abwesend").font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
                    } else {
                        AnswerMark(answer: entry.status)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            // Label before number: German needs no plural forms that way.
            Text("Zugesagt \(attendance.yes) · Vielleicht \(attendance.maybe) · Abgesagt \(attendance.no) · Offen \(attendance.open)")
        }
    }
}

/// Ja/Nein/Vielleicht for one person (oneself or a ward), with the reason the type asks for.
private struct AnswerForm: View {
    let model: AppointmentModel
    let respondents: [Answering.Respondent]
    let answered: @MainActor () async -> Void

    @State private var memberId = ""
    @State private var answer: Answer?
    @State private var reason = ""
    @State private var busy = false
    @State private var error: String?
    @State private var saved = false
    @Environment(\.theme) private var theme

    /// club-client `settings.calendar.reasonMaxLength`.
    private let reasonMaxLength = 300

    var body: some View {
        let entry = model.entry(memberId)
        let self_ = memberId == model.me.member.id
        let reasonNeeded = answer.map { Answering.needsReason($0, type: model.type) } ?? false
        Section {
            if respondents.count > 1 {
                Picker("Für", selection: $memberId) {
                    ForEach(respondents) { Text($0.name).tag($0.id) }
                }
            }
            if let entry, entry.absent {
                Group {
                    if self_ {
                        Text("Du bist an diesem Tag abwesend gemeldet; der Termin zählt als „Nein“. Mit einer Antwort änderst du das.")
                    } else {
                        Text("\(entry.name) ist an diesem Tag abwesend gemeldet; der Termin zählt als „Nein“. Mit einer Antwort änderst du das.")
                    }
                }
                .font(theme.font(.subheadline)).foregroundStyle(theme.textMuted)
            } else if entry?.unconfirmed == true {
                Text("Die Zeit hat sich geändert. Bitte die Antwort bestätigen oder ändern.")
                    .font(theme.font(.subheadline)).foregroundStyle(.orange)
            }
            Picker("Antwort", selection: $answer) {
                ForEach(Answering.choices(model.type), id: \.self) { Text(label($0)).tag(Answer?.some($0)) }
            }
            .pickerStyle(.segmented)
            TextField(reasonNeeded ? LocalizedStringKey("Begründung") : "Begründung (optional)", text: $reason)
                .onChange(of: reason) { if reason.count > reasonMaxLength { reason = String(reason.prefix(reasonMaxLength)) } }
            Button(action: submit) {
                if busy { ProgressView() } else { Text(entry?.unconfirmed == true ? LocalizedStringKey("Antwort bestätigen") : "Antwort speichern") }
            }
            .disabled(busy || answer == nil || (reasonNeeded && reason.trimmingCharacters(in: .whitespaces).isEmpty))
        } header: {
            Text("Deine Antwort")
        } footer: {
            if let error {
                Text(error).foregroundStyle(.red)
            } else if saved {
                Text("Antwort gespeichert.")
            } else {
                Text("Die Begründung sehen nur Trainer:innen des Teams, Vorstand und Admins.")
            }
        }
        .onAppear { if memberId.isEmpty, let first = respondents.first { show(first.id) } }
        .onChange(of: memberId) { show(memberId) }
    }

    /// The fields follow the chosen person's current answer.
    private func show(_ id: String) {
        memberId = id
        let entry = model.entry(id)
        answer = entry?.absent == true ? nil : entry?.status
        reason = entry?.reason ?? ""
        saved = false
        error = nil
    }

    private func label(_ answer: Answer) -> LocalizedStringKey {
        switch answer {
        case .yes: "Zusage"
        case .no: "Absage"
        case .maybe: "Vielleicht"
        }
    }

    private func submit() {
        guard let answer else { return }
        busy = true
        error = nil
        Task {
            do {
                try await model.answer(memberId, answer, reason: reason)
                saved = true
                await answered()
            } catch {
                self.error = ErrorTexts.app.text(error)
            }
            busy = false
        }
    }
}
