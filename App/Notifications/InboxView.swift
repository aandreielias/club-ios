import ClubKit
import SwiftUI

/// The notifications tab: newest first, unread ones bold; a tap opens the record where the app shows it.
struct InboxView: View {
    let model: InboxModel
    let me: Me
    let calendar: Calendar
    @State private var path: [Inbox.Target] = []
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack(path: $path) {
            List(model.inbox?.items ?? []) { item in
                Button {
                    model.open(item)
                    if let target = item.target { path.append(target) }
                } label: {
                    HStack {
                        row(item)
                        if item.target != nil {
                            Spacer()
                            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                        }
                    }
                }
                .tint(theme.text)
            }
            .brandSurface()
            .overlay {
                if model.failed {
                    LoadFailedView { Task { await model.load() } }
                } else if model.inbox == nil {
                    ProgressView()
                } else if model.inbox?.items.isEmpty == true {
                    ContentUnavailableView("Noch keine Benachrichtigungen.", systemImage: "bell")
                }
            }
            .refreshable { await model.load() }
            .navigationTitle("Mitteilungen")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        NotificationPreferencesView(model: NotificationPreferencesModel(api: model.api))
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Einstellungen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Alle gelesen") { Task { await model.markAllRead() } }
                        .disabled(model.unread == 0)
                        .accessibilityLabel("Alle als gelesen markieren")
                }
            }
            .navigationDestination(for: Inbox.Target.self) { target in
                switch target {
                case .appointment(let id):
                    AppointmentView(model: AppointmentModel(api: model.api, me: me, id: id, types: [:])) {}
                case .task(let id):
                    TaskView(model: TaskModel(api: model.api, me: me, id: id, catalog: TaskCatalog(api: model.api))) {}
                }
            }
        }
    }

    private func row(_ item: Inbox.Item) -> some View {
        let unread = item.readAt == nil
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle().fill(unread ? theme.accent : .clear).frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title).font(theme.font(.body, weight: unread ? .semibold : .regular))
                if !item.body.isEmpty {
                    Text(item.body).font(theme.font(.subheadline)).foregroundStyle(theme.textMuted).lineLimit(3)
                }
                Text(item.createdAt.formatted(.dateTime.weekday().day().month().hour().minute().club(calendar)))
                    .font(theme.font(.caption)).foregroundStyle(theme.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(unread ? .isSelected : [])
    }
}
