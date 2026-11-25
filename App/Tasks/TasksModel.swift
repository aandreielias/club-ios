import ClubKit
import Foundation
import Observation

/// The tasks tab: the member's (or all visible) tasks, as a list or grouped by the club's statuses.
@MainActor @Observable
final class TasksModel {
    let api: ApiClient
    let me: Me
    let catalog: TaskCatalog

    var mine = true
    var includeDone = false
    var board = false
    /// Nil until loaded.
    var list: TaskList?
    var failed = false
    var error: String?

    init(api: ApiClient, me: Me) {
        self.api = api
        self.me = me
        catalog = TaskCatalog(api: api)
    }

    func load() async {
        let (api, mine, done) = (api, mine, includeDone || board)  // the board always shows its done column
        async let loaded: Void = self.catalog.load()
        do {
            list = try await api.tasks(mine: mine, includeDone: done)
            failed = false
        } catch {
            failed = list == nil
        }
        await loaded
    }

    /// Board columns: the active statuses in order, each with its tasks.
    var columns: [(stage: TaskStage, tasks: [ClubTask])] {
        let tasks = list?.items ?? []
        return TaskRules.stages(catalog.stages, current: "").map { stage in (stage, tasks.filter { $0.stage == stage.key }) }
    }

    func move(_ task: ClubTask, to stage: String) async {
        error = nil
        do {
            let changed = try await api.setStage(task.id, stage)
            if let index = list?.items.firstIndex(where: { $0.id == task.id }) { list?.items[index] = changed }
        } catch {
            self.error = ErrorTexts.app.text(error)
        }
    }
}

/// The club's statuses and labels and the members' names, loaded once and shared by the task screens.
@MainActor @Observable
final class TaskCatalog {
    let api: ApiClient
    var stages: [TaskStage] = []
    var labels: [String: TaskLabel] = [:]
    var names: [String: String] = [:]

    init(api: ApiClient) {
        self.api = api
    }

    func load() async {
        let api = api
        async let stages = try? api.taskStages()
        async let labels = try? api.taskLabels()
        async let names = try? api.memberNames()
        if let stages = await stages { self.stages = stages }
        if let labels = await labels { self.labels = Dictionary(labels.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a }) }
        if let names = await names { self.names = names }
    }

    func stage(_ key: String) -> TaskStage? { stages.first { $0.key == key } }

    func name(_ memberId: String) -> String { names[memberId] ?? String(localized: "Unbekannt") }
}
