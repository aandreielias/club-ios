import Foundation
import Testing
@testable import ClubKit

private let club = try! JSONDecoder().decode(Club.self, from: Data(sdgClub.utf8))
private let calendar = Calendar.club(club)
private let decoder = ApiClient.decoder()

private func day(_ d: Int, month: Int = 11) -> Date {
    calendar.date(from: DateComponents(year: 2026, month: month, day: d))!
}

private func item(_ json: String) -> CalendarItem {
    try! decoder.decode(CalendarItem.self, from: Data(json.utf8))
}

@Test func monthGridHasWholeWeeksFromMonday() {
    let month = Month(containing: day(15), calendar: calendar)
    #expect(month.days.count == 42)  // 1 Nov 2026 is a Sunday, 30 Nov a Monday
    #expect(month.days.first == day(26, month: 10))
    #expect(month.days.last == day(6, month: 12))
    #expect(month.range.to == day(7, month: 12))
    #expect(month.adding(1).start == day(1, month: 12))
}

@Test func itemsLandOnTheirDays() {
    let month = Month(containing: day(1), calendar: calendar)
    // All-day: ends at the start of the next day (Vienna midnight = 23:00 UTC in winter).
    let holiday = item(#"{"kind":"holiday","id":"h","title":"Allerseelen","start":"2026-11-01T23:00:00Z","end":"2026-11-02T23:00:00Z","allDay":true,"category":"HOLIDAY","inactive":false}"#)
    // A point in time (task due) has no end; with fractions of a second.
    let task = item(#"{"kind":"task","id":"t","title":"Bälle","start":"2026-11-03T08:00:00.123Z","end":null,"allDay":false,"category":"TASK","inactive":false}"#)
    // Over midnight: on both days.
    let trip = item(#"{"kind":"appointment","id":"a","title":"Turnier","start":"2026-11-04T20:00:00Z","end":"2026-11-05T10:00:00Z","allDay":false,"category":"APPOINTMENT","inactive":false}"#)
    let all = [holiday, task, trip]
    #expect(month.items(all, on: day(1)).isEmpty)
    #expect(month.items(all, on: day(2)) == [holiday])
    #expect(month.items(all, on: day(3)) == [task])
    #expect(month.items(all, on: day(4)) == [trip])
    #expect(month.items(all, on: day(5)) == [trip])
}

private func appointment(team: String?, startsIn hours: Double = 48, cancelled: Bool = false) -> Appointment {
    let json = """
        {"id":"a1","teamId":\(team.map { "\"\($0)\"" } ?? "null"),"type":"MATCH","title":"Spiel","startsAt":"\(now.addingTimeInterval(hours * 3600).formatted(.iso8601))",
         "endsAt":"\(now.addingTimeInterval((hours + 2) * 3600).formatted(.iso8601))","cancelled":\(cancelled),"rides":false}
        """
    return try! decoder.decode(Appointment.self, from: Data(json.utf8))
}

private let now = Date(timeIntervalSince1970: 1_800_000_000)

private let me = try! JSONDecoder().decode(Me.self, from: Data("""
    {"member":{"id":"m1","firstName":"Anna","roles":[]},"missing":[],"teams":[{"id":"t1","name":"Damen 1"}],
     "wardIds":["k2","k1"],"wardNames":{"k1":"Ben","k2":"Clara"}}
    """.utf8))

private func type(deadline: Int = 0, maybe: Bool = true, reason: Bool = false, expect: String = "TEAM") -> AppointmentType {
    try! JSONDecoder().decode(AppointmentType.self, from: Data("""
        {"key":"MATCH","label":"Spiel","hue":"red","answerDeadlineHours":\(deadline),"allowMaybe":\(maybe),"reasonOnNo":\(reason),"expectAnswers":"\(expect)"}
        """.utf8))
}

private func attendance(_ ids: [String]) -> Attendance {
    let entries = ids.map { #"{"memberId":"\#($0)","name":"N \#($0)","status":null,"absent":false,"unconfirmed":false}"# }
    return try! JSONDecoder().decode(Attendance.self, from: Data(#"{"yes":0,"no":0,"maybe":0,"open":0,"entries":[\#(entries.joined(separator: ","))]}"#.utf8))
}

@Test func teamMemberAndListedWardsAnswer() {
    let who = Answering.respondents(appointment(team: "t1"), type: type(), attendance: attendance(["m1", "k1"]), me: me, now: now)
    #expect(who.map(\.id) == ["m1", "k1"])
    #expect(who.map(\.name) == ["Ich", "N k1"])
}

@Test func otherTeamOnlyForListedWards() {
    let who = Answering.respondents(appointment(team: "t9"), type: type(), attendance: attendance(["k2"]), me: me, now: now)
    #expect(who.map(\.id) == ["k2"])
}

@Test func clubWideEveryone() {
    let who = Answering.respondents(appointment(team: nil), type: type(), attendance: attendance([]), me: me, now: now)
    #expect(who.map(\.name) == ["Ich", "Ben", "Clara"])
}

@Test func noAnswersWhenCancelledClosedOrOff() {
    let att = attendance(["m1"])
    #expect(Answering.respondents(appointment(team: "t1", cancelled: true), type: type(), attendance: att, me: me, now: now).isEmpty)
    #expect(Answering.respondents(appointment(team: "t1", startsIn: 10), type: type(deadline: 12), attendance: att, me: me, now: now).isEmpty)
    #expect(Answering.respondents(appointment(team: "t1"), type: type(expect: "NONE"), attendance: att, me: me, now: now).isEmpty)
}

@Test func typeRulesForChoicesAndReason() {
    #expect(Answering.choices(type(maybe: false)) == [.yes, .no])
    #expect(Answering.needsReason(.no, type: type(reason: true)))
    #expect(!Answering.needsReason(.yes, type: type(reason: true)))
}
