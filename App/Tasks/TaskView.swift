import ClubKit
import SwiftUI

/// One task: status, facts, needs and files, checklist, comments.
struct TaskView: View {
    @State var model: TaskModel
    /// Tells the list to reload after a change.
    let changed: () async -> Void

    @State private var comment = ""
    @Environment(\.theme) private var theme
    @Environment(\.calendar) private var calendar

    /// club-client `settings.tasks.commentMaxLength`.
    private let commentMaxLength = 2000

    var body: some View {
        List {
            if let task = model.task { content(task) }
        }
        .brandSurface()
        .overlay {
            if model.failed {
                LoadFailedView { Task { await model.load() } }
            } else if model.task == nil {
                ProgressView()
            }
        }
        .refreshable { await model.load() }
        .task { if model.task == nil { await model.load() } }
        .navigationTitle("Aufgabe")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { Task { await changed() } }
    }

    @ViewBuilder
    private func content(_ task: ClubTask) -> some View {
        Section {
            Text(task.title).heading(.title3)
            if model.mayWork {
                Picker("Status", selection: Binding(get: { task.stage }, set: { stage in Task { await model.setStage(stage) } })) {
                    ForEach(TaskRules.stages(model.catalog.stages, current: task.stage)) { Text($0.label).tag($0.key) }
                }
                .disabled(model.busy)
            } else {
                LabeledContent("Status", value: model.catalog.stage(task.stage)?.label ?? task.stage)
            }
            LabeledContent("Zugewiesen", value: task.assignees.isEmpty ? String(localized: "Niemand") : task.assignees.map(model.catalog.name).joined(separator: ", "))
            LabeledContent("Fällig") {
                if let due = task.dueAt {
                    Text(due.formatted(.dateTime.weekday().day().month().year().hour().minute().club(calendar)))
                        .foregroundStyle(task.overdue() ? .red : theme.textMuted)
                } else {
                    Text("Ohne Termin")
                }
            }
            if let rhythm = TaskRules.repeatLabel(task) { LabeledContent("Wiederholt", value: rhythm) }
            if task.priority != .normal {
                LabeledContent("Priorität", value: task.priority == .high ? String(localized: "Hoch") : String(localized: "Niedrig"))
            }
            if !task.labels.isEmpty {
                LabeledContent("Labels", value: task.labels.map { model.catalog.labels[$0]?.label ?? $0 }.joined(separator: ", "))
            }
            LabeledContent("Erstellt", value: "\(task.createdAt.formatted(.dateTime.day().month().year().club(calendar))), \(model.catalog.name(task.createdBy))")
            if let done = task.completedAt {
                LabeledContent("Erledigt", value: done.formatted(.dateTime.day().month().year().hour().minute().club(calendar)))
            }
        } footer: {
            if let error = model.error { Text(error).foregroundStyle(.red) }
        }

        if let text = task.description, !text.isEmpty {
            Section("Beschreibung") { Text(text) }
        }

        if task.parent != nil || !task.subtasks.isEmpty || !task.blockedBy.isEmpty {
            Section {
                if let parent = task.parent { linkRow("Teil von", parent) }
                ForEach(task.subtasks) { linkRow("Unteraufgabe", $0) }
                ForEach(task.blockedBy) { linkRow("Wartet auf", $0) }
            }
        }

        if let links = model.links, !links.needs.isEmpty || !links.files.isEmpty {
            Section("Benötigt") {
                ForEach(links.needs) { need in
                    Text("\(need.quantity) × \(need.name)").strikethrough(need.deleted)
                }
                // shortcut: files are listed only; opening them comes with the Dateien area.
                ForEach(links.files) { file in
                    Label(file.name, systemImage: "doc").strikethrough(file.deleted)
                }
            }
        }

        if !task.checklist.isEmpty {
            Section {
                ForEach(task.checklist) { item in
                    Button { Task { await model.check(item) } } label: {
                        Label {
                            Text(item.text).strikethrough(item.done).foregroundStyle(item.done ? theme.textMuted : theme.text)
                        } icon: {
                            Image(systemName: item.done ? "checkmark.square.fill" : "square")
                        }
                    }
                    .disabled(!model.mayWork || model.busy)
                }
            } header: {
                Text("Checkliste \(task.checklist.filter(\.done).count)/\(task.checklist.count)")
            }
        }

        Section("Kommentare") {
            if task.comments.isEmpty {
                Text("Noch keine Kommentare.").foregroundStyle(theme.textMuted)
            }
            ForEach(task.comments) { comment in
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(model.catalog.name(comment.authorId)) · \(comment.createdAt.formatted(.dateTime.day().month().hour().minute().club(calendar)))")
                        .font(theme.font(.caption)).foregroundStyle(theme.textMuted)
                    Text(comment.text)
                }
            }
            TextField("Kommentar", text: $comment, axis: .vertical)
                .onChange(of: comment) { if comment.count > commentMaxLength { comment = String(comment.prefix(commentMaxLength)) } }
            Button("Kommentieren") {
                Task { if await model.comment(comment) { comment = "" } }
            }
            .disabled(comment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.busy)
        }
    }

    private func linkRow(_ label: LocalizedStringKey, _ link: ClubTask.Link) -> some View {
        // A destination, not a value: task views also open from the inbox and calendar stacks.
        NavigationLink {
            TaskView(model: TaskModel(api: model.api, me: model.me, id: link.id, catalog: model.catalog), changed: changed)
        } label: {
            LabeledContent(label) {
                Text(link.title).strikethrough(link.status == .done)
            }
        }
    }
}
