import ClubKit
import Foundation
import Observation

/// The member's and their wards' current and future absences.
@MainActor @Observable
final class AbsencesModel {
    let api: ApiClient
    let me: Me
    let calendar: Calendar

    /// Nil until loaded.
    var absences: [Absence]?
    var failed = false
    var error: String?

    init(api: ApiClient, me: Me, calendar: Calendar) {
        self.api = api
        self.me = me
        self.calendar = calendar
    }

    func load() async {
        do {
            absences = try await api.absences().sorted { $0.from < $1.from }
            failed = false
        } catch {
            failed = absences == nil
        }
    }

    func name(_ memberId: String) -> String {
        memberId == me.member.id ? String(localized: "Ich") : me.wardNames[memberId] ?? memberId
    }

    /// Throws the readable text, for the form to show.
    func add(_ body: AbsenceBody, key: String) async throws {
        _ = try await api.addAbsence(body, key: key)
        await load()
    }

    func delete(_ absence: Absence) async {
        error = nil
        do {
            try await api.deleteAbsence(absence.id)
            absences?.removeAll { $0.id == absence.id }
        } catch {
            self.error = ErrorTexts.app.text(error)
        }
    }
}
