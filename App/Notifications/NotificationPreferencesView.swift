import ClubKit
import Observation
import SwiftUI

/// Per kind whether it also comes by push and e-mail; the club's important kinds always do.
@MainActor @Observable
final class NotificationPreferencesModel {
    let api: ApiClient
    /// In the web's order; nil until loaded.
    var items: [NotificationPreference]?
    var important: Set<String> = []
    var failed = false
    var error: String?

    init(api: ApiClient) {
        self.api = api
    }

    func load() async {
        let api = api
        async let settings = try? api.notificationSettings()
        do {
            let stored = try await api.notificationPreferences()
            let order = NotificationKinds.all.map(\.kind)
            items = stored.sorted { (order.firstIndex(of: $0.kind) ?? .max) < (order.firstIndex(of: $1.kind) ?? .max) }
            failed = false
        } catch {
            failed = items == nil
        }
        important = Set(await settings?.importantKinds ?? [])
    }

    /// Saves every kind at once (the server takes the whole list); a refusal puts the switch back.
    func save(_ changed: NotificationPreference) async {
        guard let before = items, let index = before.firstIndex(where: { $0.kind == changed.kind }) else { return }
        items?[index] = changed
        error = nil
        do {
            try await api.saveNotificationPreferences(items ?? [])
        } catch {
            items = before
            self.error = ErrorTexts.app.text(error)
        }
    }
}

struct NotificationPreferencesView: View {
    @State var model: NotificationPreferencesModel
    @Environment(\.theme) private var theme

    var body: some View {
        List {
            Section {
            } footer: {
                Text("Im Posteingang erscheint jede Benachrichtigung. Hier legst du fest, was zusätzlich per Push (App) und per E-Mail kommt.")
            }
            ForEach(model.items ?? []) { pref in
                let kind = NotificationKinds.all.first { $0.kind == pref.kind }
                let fixed = model.important.contains(pref.kind)
                Section {
                    Toggle("Push (App)", isOn: binding(pref, \.push)).disabled(fixed)
                    Toggle("E-Mail", isOn: binding(pref, \.email)).disabled(fixed)
                } header: {
                    Text(kind?.label ?? pref.kind)
                } footer: {
                    Text(fixed ? String(localized: "Der Verein sendet diese Art immer.") : kind?.hint ?? "")
                }
            }
            if let error = model.error {
                Text(error).foregroundStyle(.red)
            }
        }
        .brandSurface()
        .overlay {
            if model.failed {
                LoadFailedView { Task { await model.load() } }
            } else if model.items == nil {
                ProgressView()
            }
        }
        .task { if model.items == nil { await model.load() } }
        .navigationTitle("Benachrichtigungen")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Important kinds show on, whatever is stored.
    private func binding(_ pref: NotificationPreference, _ channel: WritableKeyPath<NotificationPreference, Bool>) -> Binding<Bool> {
        Binding(
            get: { model.important.contains(pref.kind) || pref[keyPath: channel] },
            set: { value in
                var changed = pref
                changed[keyPath: channel] = value
                Task { await model.save(changed) }
            })
    }
}
