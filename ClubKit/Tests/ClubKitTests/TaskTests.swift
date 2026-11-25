import Foundation
import Testing
@testable import ClubKit

private let me = try! JSONDecoder().decode(Me.self, from: Data("""
    {"member":{"id":"m1","firstName":"Anna","roles":["PLAYER"]},"missing":[],"teams":[{"id":"t1","name":"Damen 1"}],
     "wardIds":["k1"],"wardNames":{"k1":"Ben"}}
    """.utf8))

private func task(teamId: String? = nil, createdBy: String = "x", assignees: [String] = [], due: String? = nil,
                  weeks: Int? = nil, months: Int? = nil, byWeekday: Bool = false) -> ClubTask {
    func json(_ v: Any?) -> String { v.map { $0 is String ? "\"\($0)\"" : "\($0)" } ?? "null" }
    return try! ApiClient.decoder().decode(ClubTask.self, from: Data("""
        {"id":"x1","teamId":\(json(teamId)),"title":"T","description":null,"status":"OPEN","stage":"S","dueAt":\(json(due)),
         "createdBy":"\(createdBy)","assignees":[\(assignees.map { "\"\($0)\"" }.joined(separator: ","))],"checklist":[],"comments":[],
         "createdAt":"2026-01-01T10:00:00Z","completedAt":null,"repeatWeeks":\(json(weeks)),"repeatMonths":\(json(months)),
         "repeatByWeekday":\(byWeekday),"priority":"NORMAL","labels":[],"parent":null,"subtasks":[],"blockedBy":[]}
        """.utf8))
}

@Test func workersAreCreatorAssigneesGuardiansAndBoard() {
    #expect(!TaskRules.mayWork(task(), me: me))
    #expect(TaskRules.mayWork(task(createdBy: "m1"), me: me))
    #expect(TaskRules.mayWork(task(assignees: ["k1"]), me: me))
    #expect(!TaskRules.mayWork(task(teamId: "t1"), me: me), "a player of the team only reads it")
}

@Test func overdueOnlyWhenOpenAndPastDue() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(task(due: "2020-01-01T00:00:00Z").overdue(now: now))
    #expect(!task(due: "2099-01-01T00:00:00Z").overdue(now: now))
    #expect(!task().overdue(now: now))
}

@Test func repeatLabelsLikeTheWeb() {
    #expect(TaskRules.repeatLabel(task()) == nil)
    #expect(TaskRules.repeatLabel(task(weeks: 1)) == "Jede Woche")
    #expect(TaskRules.repeatLabel(task(weeks: 3)) == "Alle 3 Wochen")
    #expect(TaskRules.repeatLabel(task(months: 12)) == "Jedes Jahr")
    #expect(TaskRules.repeatLabel(task(months: 2, byWeekday: true)) == "Alle 2 Monate am selben Wochentag")
}

@Test func stagesKeepTheTasksArchivedOne() throws {
    let stages = try JSONDecoder().decode([TaskStage].self, from: Data("""
        [{"key":"B","label":"Erledigt","hue":"green","phase":"DONE","sort":2,"archived":false},
         {"key":"A","label":"Offen","hue":"red","phase":"OPEN","sort":0,"archived":false},
         {"key":"Z","label":"Alt","hue":"gray","phase":"OPEN","sort":1,"archived":true}]
        """.utf8))
    #expect(TaskRules.stages(stages, current: "B").map(\.key) == ["A", "B"])
    #expect(TaskRules.stages(stages, current: "Z").map(\.key) == ["A", "Z", "B"])
}
