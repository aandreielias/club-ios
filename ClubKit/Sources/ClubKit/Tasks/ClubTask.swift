import Foundation

/// A task (`TasksApi.TaskDto`); named `ClubTask` so it does not hide Swift's `Task`.
public struct ClubTask: Decodable, Sendable, Identifiable {
    public let id: String
    /// Nil = a club task.
    public let teamId: String?
    public let title: String
    public let description: String?
    /// The phase the rules read; `stage` is the club's status inside it.
    public let status: Phase
    public let stage: String
    public let dueAt: Date?
    public let createdBy: String
    public let assignees: [String]
    public let checklist: [ChecklistItem]
    /// Only `GET /tasks/{id}` fills them.
    public let comments: [Comment]
    public let createdAt: Date
    public let completedAt: Date?
    public let repeatWeeks: Int?
    public let repeatMonths: Int?
    public let repeatByWeekday: Bool
    public let priority: Priority
    /// Keys of the club's labels.
    public let labels: [String]
    public let parent: Link?
    public let subtasks: [Link]
    public let blockedBy: [Link]

    public enum Phase: String, Codable, Sendable { case open = "OPEN", inProgress = "IN_PROGRESS", done = "DONE" }
    public enum Priority: String, Decodable, Sendable { case low = "LOW", normal = "NORMAL", high = "HIGH" }

    public struct ChecklistItem: Decodable, Sendable, Identifiable {
        public let id: String
        public let text: String
        public let done: Bool
    }

    public struct Comment: Decodable, Sendable, Identifiable {
        public let id: String
        public let authorId: String
        public let text: String
        public let createdAt: Date
    }

    /// Another task as this one names it (parent, subtask, blocker); only those the reader sees.
    public struct Link: Decodable, Sendable, Identifiable, Hashable {
        public let id: String
        public let title: String
        public let status: Phase
    }

    public func overdue(now: Date = Date()) -> Bool {
        status != .done && dueAt.map { $0 < now } == true
    }
}

/// `GET /tasks`: at most 1000, `truncated` when cut.
public struct TaskList: Decodable, Sendable {
    public let items: [ClubTask]
    public let truncated: Bool
}

/// The club's statuses (board columns), each inside a fixed phase.
public struct TaskStage: Decodable, Sendable, Identifiable {
    public let key: String
    public let label: String
    public let hue: String
    public let phase: ClubTask.Phase
    public let sort: Int
    public let archived: Bool
    public var id: String { key }
}

public struct TaskLabel: Decodable, Sendable {
    public let key: String
    public let label: String
    public let hue: String
}

/// What an appointment or task needs: items from the inventory and attached files.
public struct RecordLinks: Decodable, Sendable {
    public let needs: [Need]
    public let files: [File]

    public struct Need: Decodable, Sendable, Identifiable {
        public let itemId: String
        public let name: String
        public let quantity: Int
        public let deleted: Bool
        public var id: String { itemId }
    }

    public struct File: Decodable, Sendable, Identifiable {
        public let id: String
        public let name: String
        public let deleted: Bool
    }
}

/// Every member's name by id (`GET /members/names`; not for guests).
public struct MemberNames: Decodable, Sendable {
    public let names: [String: String]
}

/// `PUT /tasks/{id}/status`: one of the two.
public struct StatusBody: Encodable, Sendable {
    public let status: ClubTask.Phase?
    public let stage: String?
}

public struct CheckBody: Encodable, Sendable {
    public let done: Bool
}

public struct CommentBody: Encodable, Sendable {
    public let text: String
}

/// The rules the screens need, mirrored from club-client's `TaskPolicy` (the server decides).
public enum TaskRules {
    /// Change the status, tick checklist items: board/admin, the creator, assignees (or their guardians), coaches of the team.
    // shortcut: "coach of the team" = COACH role + member of the team; the web asks the roster's team role. Upgrade with the coach tools.
    public static func mayWork(_ task: ClubTask, me: Me) -> Bool {
        let roles = Set(me.member.roles)
        let selves = Set([me.member.id] + me.wardIds)
        if !roles.isDisjoint(with: ["ADMIN", "BOARD"]) || task.createdBy == me.member.id { return true }
        if task.assignees.contains(where: selves.contains) { return true }
        return roles.contains("COACH") && task.teamId.map { id in me.teams.contains { $0.id == id } } == true
    }

    /// The statuses offered for a task: the active ones in board order, plus its own when archived.
    public static func stages(_ all: [TaskStage], current: String) -> [TaskStage] {
        all.filter { !$0.archived || $0.key == current }.sorted { ($0.sort, $0.label) < ($1.sort, $1.label) }
    }

    /// "Jede Woche", "Alle 3 Monate", … like club-client's `repeatLabel`; nil = once.
    public static func repeatLabel(_ task: ClubTask) -> String? {
        if let weeks = task.repeatWeeks {
            return weeks == 1 ? "Jede Woche" : "Alle \(weeks) Wochen"
        }
        guard let months = task.repeatMonths else { return nil }
        switch (months, task.repeatByWeekday) {
        case (1, false): return "Jeden Monat am selben Tag"
        case (1, true): return "Jeden Monat am selben Wochentag (z. B. 2. Dienstag)"
        case (12, false): return "Jedes Jahr"
        case (_, false): return "Alle \(months) Monate"
        case (_, true): return "Alle \(months) Monate am selben Wochentag"
        }
    }
}

extension ApiClient {
    /// Visible tasks by due date (undated last), without comments. `mine` = assigned to the member or their minors.
    public func tasks(mine: Bool, includeDone: Bool) async throws -> TaskList {
        try await get("/api/v1/tasks", query: ["mine": String(mine), "includeDone": String(includeDone)])
    }

    public func task(_ id: String) async throws -> ClubTask {
        try await get("/api/v1/tasks/\(id)")
    }

    /// Moves the task to one of the club's statuses (its phase follows).
    public func setStage(_ id: String, _ stage: String) async throws -> ClubTask {
        try await put("/api/v1/tasks/\(id)/status", StatusBody(status: nil, stage: stage))
    }

    public func check(_ id: String, item: String, done: Bool) async throws -> ClubTask {
        try await put("/api/v1/tasks/\(id)/checklist/\(item)", CheckBody(done: done))
    }

    public func comment(_ id: String, _ text: String, key: String) async throws -> ClubTask {
        try await post("/api/v1/tasks/\(id)/comments", CommentBody(text: text), key: key)
    }

    public func taskStages() async throws -> [TaskStage] {
        let answer: Items<TaskStage> = try await get("/api/v1/tasks/stages")
        return answer.items
    }

    public func taskLabels() async throws -> [TaskLabel] {
        let answer: Items<TaskLabel> = try await get("/api/v1/tasks/labels")
        return answer.items
    }

    public func taskLinks(_ id: String) async throws -> RecordLinks {
        try await get("/api/v1/tasks/\(id)/links")
    }

    public func memberNames() async throws -> [String: String] {
        let answer: MemberNames = try await get("/api/v1/members/names")
        return answer.names
    }
}
