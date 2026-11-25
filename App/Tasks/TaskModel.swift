import ClubKit
import Foundation
import Observation

/// One task with its links; status, checklist and comments for who works on it.
@MainActor @Observable
final class TaskModel {
    let api: ApiClient
    let me: Me
    let id: String
    let catalog: TaskCatalog

    var task: ClubTask?
    var links: RecordLinks?
    var failed = false
    var busy = false
    var error: String?
    /// One Idempotency-Key per comment, renewed once it is posted.
    private var commentKey = UUID().uuidString

    init(api: ApiClient, me: Me, id: String, catalog: TaskCatalog) {
        self.api = api
        self.me = me
        self.id = id
        self.catalog = catalog
    }

    var mayWork: Bool { task.map { TaskRules.mayWork($0, me: me) } ?? false }

    func load() async {
        let (api, id) = (api, id)
        async let links = try? api.taskLinks(id)
        if catalog.stages.isEmpty { await catalog.load() }
        do {
            task = try await api.task(id)
            failed = false
        } catch {
            failed = task == nil
        }
        self.links = await links
    }

    func setStage(_ stage: String) async {
        let (api, id) = (api, id)
        await run { try await api.setStage(id, stage) }
    }

    func check(_ item: ClubTask.ChecklistItem) async {
        let (api, id) = (api, id)
        await run { try await api.check(id, item: item.id, done: !item.done) }
    }

    /// True when the comment went through.
    func comment(_ text: String) async -> Bool {
        let (api, id, key) = (api, id, commentKey)
        let ok = await run { try await api.comment(id, text.trimmingCharacters(in: .whitespacesAndNewlines), key: key) }
        if ok { commentKey = UUID().uuidString }
        return ok
    }

    @discardableResult
    private func run(_ call: @escaping @Sendable () async throws -> ClubTask) async -> Bool {
        busy = true
        error = nil
        defer { busy = false }
        do {
            task = try await call()
            return true
        } catch {
            self.error = ErrorTexts.app.text(error)
            return false
        }
    }
}
