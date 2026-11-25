import ClubKit
import Foundation
import Observation

/// One appointment with its attendance, and the member's answers for themselves and their wards.
@MainActor @Observable
final class AppointmentModel {
    let api: ApiClient
    let me: Me
    let id: String
    let types: [String: AppointmentType]

    var appointment: Appointment?
    var attendance: Attendance?
    var failed = false

    init(api: ApiClient, me: Me, id: String, types: [String: AppointmentType]) {
        self.api = api
        self.me = me
        self.id = id
        self.types = types
    }

    var type: AppointmentType? { appointment.flatMap { types[$0.type] } }

    func load() async {
        let (api, id) = (api, id)
        do {
            async let appointment = api.appointment(id)
            // Types without answers have no attendance worth showing; a refusal leaves only the facts.
            async let attendance = try? api.attendance(of: id)
            self.appointment = try await appointment
            self.attendance = await attendance
            failed = false
        } catch {
            failed = true
        }
    }

    func respondents(now: Date = Date()) -> [Answering.Respondent] {
        guard let appointment else { return [] }
        return Answering.respondents(appointment, type: type, attendance: attendance, me: me, now: now)
    }

    func entry(_ memberId: String) -> Attendance.Entry? {
        attendance?.entries.first { $0.memberId == memberId }
    }

    func answer(_ memberId: String, _ answer: Answer, reason: String) async throws {
        let text = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        try await api.answer(id, AnswerBody(memberId: memberId, status: answer, reason: text.isEmpty ? nil : text))
        attendance = try? await api.attendance(of: id)
    }
}
