import Foundation

/// The member's notifications, newest first (`GET /api/v1/me/notifications`).
public struct Inbox: Decodable, Sendable {
    public var items: [Item]
    public var unread: Int

    public struct Item: Decodable, Sendable, Identifiable {
        public let id: String
        /// `NotificationsApi.NotificationKind`, e.g. TASK_ASSIGNED.
        public let kind: String
        public let title: String
        public let body: String
        /// Server link, e.g. `/appointments/<id>`.
        public let link: String?
        public let createdAt: Date
        public var readAt: Date?

        /// The record the link opens in the app; nil for records the app cannot show yet.
        public var target: Target? {
            let parts = (link ?? "").split(separator: "/").map(String.init)
            guard parts.count == 2 else { return nil }
            switch parts[0] {
            case "appointments": return .appointment(parts[1])
            default: return nil
            }
        }
    }

    public enum Target: Hashable, Sendable {
        case appointment(String)
    }
}

/// Per kind whether it also comes by push and by e-mail (the inbox gets every one).
public struct NotificationPreference: Codable, Sendable, Identifiable {
    public let kind: String
    public var push: Bool
    public var email: Bool

    public var id: String { kind }
}

/// The club's rules the member's settings show (`GET /api/v1/notifications/settings`).
public struct NotificationSettings: Decodable, Sendable {
    /// Always go out by push and e-mail; the member cannot switch them off.
    public let importantKinds: [String]
}

struct PreferenceList: Codable { let items: [NotificationPreference] }

private struct ReadBody: Encodable { let read: Bool }

extension ApiClient {
    public func inbox() async throws -> Inbox {
        try await get("/api/v1/me/notifications")
    }

    public func markRead(_ id: String) async throws {
        try await patch("/api/v1/me/notifications/\(id)", ReadBody(read: true))
    }

    public func markAllRead() async throws {
        try await post("/api/v1/me/notifications/read-all")
    }

    public func notificationPreferences() async throws -> [NotificationPreference] {
        let answer: PreferenceList = try await get("/api/v1/me/notification-preferences")
        return answer.items
    }

    public func saveNotificationPreferences(_ items: [NotificationPreference]) async throws {
        try await put("/api/v1/me/notification-preferences", PreferenceList(items: items))
    }

    public func notificationSettings() async throws -> NotificationSettings {
        try await get("/api/v1/notifications/settings")
    }
}
