import Foundation

/// Who may answer an appointment, ported from club-client `AppointmentPolicy` (the server decides again:
/// `AttendanceAccess.selfOrWard`).
public enum Answering {
    public struct Respondent: Equatable, Sendable, Identifiable {
        public let id: String
        /// "Ich" for the member, else the ward's name.
        public let name: String
    }

    /// Answers close `deadlineHours` before the start (the type's answer deadline).
    public static func closed(_ appointment: Appointment, deadlineHours: Int, now: Date) -> Bool {
        appointment.startsAt.addingTimeInterval(-Double(deadlineHours) * 3600) <= now
    }

    /// The member and their wards, as far as they belong to the appointment (its team's attendance list; anyone when club-wide).
    /// Empty when cancelled, closed, or the type takes no answers.
    public static func respondents(_ appointment: Appointment, type: AppointmentType?, attendance: Attendance?, me: Me, now: Date) -> [Respondent] {
        if appointment.cancelled || type?.expectAnswers == "NONE" || closed(appointment, deadlineHours: type?.answerDeadlineHours ?? 0, now: now) {
            return []
        }
        let entries = attendance?.entries ?? []
        func listed(_ id: String) -> Bool { appointment.teamId == nil || entries.contains { $0.memberId == id } }
        let inTeam = appointment.teamId.map { team in me.teams.contains { $0.id == team } } ?? false
        var out = listed(me.member.id) || inTeam ? [Respondent(id: me.member.id, name: "Ich")] : []
        for ward in me.wardIds.sorted() where listed(ward) {
            out.append(Respondent(id: ward, name: entries.first { $0.memberId == ward }?.name ?? me.wardNames[ward] ?? "Kind"))
        }
        return out
    }

    /// Text the server refuses: a reason is required for "no" when the type says so.
    public static func needsReason(_ answer: Answer, type: AppointmentType?) -> Bool {
        answer == .no && type?.reasonOnNo == true
    }

    /// The answers the type offers.
    public static func choices(_ type: AppointmentType?) -> [Answer] {
        type?.allowMaybe == false ? [.yes, .no] : [.yes, .no, .maybe]
    }
}
