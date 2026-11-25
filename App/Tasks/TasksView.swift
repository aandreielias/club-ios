import ClubKit
import SwiftUI

/// The tasks tab: a list by due date, or a board grouped by the club's statuses; long press moves a task.
struct TasksView: View {
    @State var model: TasksModel
    @Environment(\.theme) private var theme

    var body: some View {
        NavigationStack {
            List {
                if model.board {
                    ForEach(model.columns, id: \.stage.key) { column in
                        Section {
                            if column.tasks.isEmpty {
                                Text("Keine Aufgaben").foregroundStyle(theme.textMuted)
                            }
                            ForEach(column.tasks) { row($0) }
                        } header: {
                            HStack {
                                Circle().fill(Color(hue: column.stage.hue)).frame(width: 8, height: 8)
                                Text(column.stage.label)
                                Text("\(column.tasks.count)").foregroundStyle(theme.textMuted)
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(model.list?.items ?? []) { row($0) }
                    } footer: {
                        if model.list?.truncated == true {
                            Text("Es gibt mehr Aufgaben, als die Liste zeigt. Bitte Filter eingrenzen.")
                        }
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
                } else if model.list == nil {
                    ProgressView()
                } else if model.list?.items.isEmpty == true && !model.board {
                    ContentUnavailableView(model.mine ? LocalizedStringKey("Keine offenen Aufgaben für dich.") : "Keine offenen Aufgaben.", systemImage: "checklist")
                }
            }
            .refreshable { await model.load() }
            .task { if model.list == nil { await model.load() } }
            .navigationTitle("Aufgaben")
            .toolbar { toolbar }
            .navigationDestination(for: TaskRoute.self) { route in
                TaskView(model: TaskModel(api: model.api, me: model.me, id: route.id, catalog: model.catalog)) {
                    await model.load()
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { model.board.toggle(); Task { await model.load() } } label: {
                Image(systemName: model.board ? "list.bullet" : "rectangle.split.3x1")
            }
            .accessibilityLabel(model.board ? "Liste" : "Tafel")
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Toggle("Nur meine", isOn: reloading(\.mine))
                if !model.board { Toggle("Erledigte zeigen", isOn: reloading(\.includeDone)) }
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
            }
            .accessibilityLabel("Filter")
        }
    }

    private func reloading(_ path: ReferenceWritableKeyPath<TasksModel, Bool>) -> Binding<Bool> {
        Binding(get: { model[keyPath: path] }, set: { model[keyPath: path] = $0; Task { await model.load() } })
    }

    private func row(_ task: ClubTask) -> some View {
        NavigationLink(value: TaskRoute(id: task.id)) {
            TaskRow(task: task, catalog: model.catalog, showStage: !model.board)
        }
        .contextMenu {
            if TaskRules.mayWork(task, me: model.me) {
                ForEach(TaskRules.stages(model.catalog.stages, current: task.stage)) { stage in
                    Button(stage.label) { Task { await model.move(task, to: stage.key) } }
                        .disabled(stage.key == task.stage)
                }
            }
        }
    }
}

struct TaskRoute: Hashable {
    let id: String
}

/// Title, due date (red when overdue), status, checklist progress, assignees.
struct TaskRow: View {
    let task: ClubTask
    let catalog: TaskCatalog
    let showStage: Bool
    @Environment(\.theme) private var theme
    @Environment(\.calendar) private var calendar

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                if task.priority == .high {
                    Image(systemName: "exclamationmark").foregroundStyle(.red).accessibilityLabel("Priorität hoch")
                }
                Text(task.title).strikethrough(task.status == .done).foregroundStyle(task.status == .done ? theme.textMuted : theme.text)
                Spacer()
                if showStage, let stage = catalog.stage(task.stage) {
                    Text(stage.label).font(theme.font(.caption)).padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(hue: stage.hue).opacity(0.18), in: Capsule())
                }
            }
            HStack(spacing: 10) {
                if let due = task.dueAt {
                    Label(due.formatted(.dateTime.weekday().day().month().hour().minute().club(calendar)), systemImage: "clock")
                        .foregroundStyle(task.overdue() ? .red : theme.textMuted)
                }
                if !task.checklist.isEmpty {
                    Label("\(task.checklist.filter(\.done).count)/\(task.checklist.count)", systemImage: "checklist")
                }
                if !task.assignees.isEmpty {
                    Text(task.assignees.map(catalog.name).joined(separator: ", ")).lineLimit(1)
                }
            }
            .font(theme.font(.subheadline))
            .foregroundStyle(theme.textMuted)
            .labelStyle(.titleAndIcon)
        }
        .accessibilityElement(children: .combine)
    }
}
