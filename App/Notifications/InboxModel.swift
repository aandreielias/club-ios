import ClubKit
import Foundation
import Observation

/// The member's inbox; owned by the tab bar so the badge shows the unread count.
@MainActor @Observable
final class InboxModel {
    let api: ApiClient

    /// Nil until loaded.
    var inbox: Inbox?
    var failed = false

    init(api: ApiClient) {
        self.api = api
    }

    var unread: Int { inbox?.unread ?? 0 }

    func load() async {
        do {
            inbox = try await api.inbox()
            failed = false
        } catch {
            failed = inbox == nil
        }
    }

    /// Marks it read here at once and on the server; a failure is corrected by the next load.
    func open(_ item: Inbox.Item) {
        guard item.readAt == nil, let index = inbox?.items.firstIndex(where: { $0.id == item.id }) else { return }
        inbox?.items[index].readAt = Date()
        inbox?.unread = max((inbox?.unread ?? 1) - 1, 0)
        let api = api
        Task { try? await api.markRead(item.id) }
    }

    func markAllRead() async {
        guard (try? await api.markAllRead()) != nil else { return }
        await load()
    }
}
