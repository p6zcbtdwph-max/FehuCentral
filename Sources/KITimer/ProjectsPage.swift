import SwiftUI

struct ProjectsPage: View {
    @EnvironmentObject var tracker: ProjectTracker
    @State private var showEditor = false
    @State private var editingProject: Project? = nil
    @State private var exportAlert = false
    @State private var exportText = ""

    var body: some View {
        VStack(spacing: 0) {
            if showEditor {
                ProjectEditorView(
                    project: editingProject,
                    onSave: { name, emoji in
                        if var p = editingProject {
                            p.name = name; p.emoji = emoji
                            tracker.updateProject(p)
                        } else {
                            tracker.addProject(name: name, emoji: emoji)
                        }
                        showEditor = false; editingProject = nil
                    },
                    onCancel: { showEditor = false; editingProject = nil }
                )
            } else {
                listView
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            if tracker.projects.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 28)).foregroundStyle(.secondary)
                    Text("Noch keine Projekte")
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                    Button("Erstes Projekt anlegen") {
                        editingProject = nil; showEditor = true
                    }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                }
                .frame(maxWidth: .infinity).padding(.vertical, 28)
            } else {
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(tracker.projects) { project in
                            ProjectRow(project: project)
                                .contentShape(Rectangle())
                                .onTapGesture { tracker.toggle(project) }
                                .contextMenu {
                                    Button("Bearbeiten") {
                                        editingProject = project; showEditor = true
                                    }
                                    Divider()
                                    Button("Löschen", role: .destructive) {
                                        tracker.deleteProject(id: project.id)
                                    }
                                }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 260)

                // Tages-Summe
                if tracker.totalTodayDuration > 0 {
                    Divider()
                    HStack {
                        Text("Heute gesamt")
                            .font(.system(size: 11)).foregroundStyle(.secondary)
                        Spacer()
                        Text(tracker.totalTodayDuration.hhmm)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 6)
                }
            }

            Divider()

            HStack {
                Button(action: { editingProject = nil; showEditor = true }) {
                    Label("Projekt hinzufügen", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain).foregroundStyle(.blue)

                Spacer()

                if !tracker.entries.isEmpty {
                    Button(action: exportCSV) {
                        Label("CSV", systemImage: "arrow.down.doc")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .alert("Export", isPresented: $exportAlert) {
            Button("OK") {}
        } message: {
            Text(exportText)
        }
    }

    private func exportCSV() {
        let csv = tracker.exportCSV()
        let name = "fehu-central-\(formattedDate()).csv"
        let url  = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(name)
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        exportText = "Gespeichert in Downloads/\(name)"
        exportAlert = true
    }

    private func formattedDate() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}

// MARK: - Projekt-Zeile

struct ProjectRow: View {
    let project: Project
    @EnvironmentObject var tracker: ProjectTracker
    @State private var hovered = false

    private var isActive: Bool { tracker.activeProject?.id == project.id }
    private var todayDur: TimeInterval { tracker.todayDuration(for: project) }
    private var weekDur:  TimeInterval { tracker.weekDuration(for: project)  }

    var body: some View {
        HStack(spacing: 10) {
            // Emoji + aktiver Indikator
            ZStack(alignment: .bottomTrailing) {
                Text(project.emoji)
                    .font(.system(size: 22))
                if isActive {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 30)

            // Name + Woche
            VStack(alignment: .leading, spacing: 1) {
                Text(project.name)
                    .font(.system(size: 13, weight: isActive ? .semibold : .regular))
                if weekDur > 0 {
                    Text("Woche: \(weekDur.hhmm)")
                        .font(.system(size: 10)).foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Heute / Live-Timer
            VStack(alignment: .trailing, spacing: 1) {
                if isActive {
                    Text(tracker.elapsed.hhmmss)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.green)
                    Text("läuft")
                        .font(.system(size: 9)).foregroundStyle(.green)
                } else if todayDur > 60 {
                    Text(todayDur.hhmm)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("heute")
                        .font(.system(size: 9)).foregroundStyle(.secondary)
                } else {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.secondary).opacity(hovered ? 1 : 0.4)
                }
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 7)
        .background(
            isActive
                ? Color.green.opacity(0.07)
                : (hovered ? Color.secondary.opacity(0.07) : Color.clear)
        )
        .onHover { hovered = $0 }
    }
}

// MARK: - Projekt-Editor

struct ProjectEditorView: View {
    @State private var name: String
    @State private var emoji: String
    let isNew: Bool
    let onSave: (String, String) -> Void
    let onCancel: () -> Void

    private let quickEmojis = ["💼","🚀","🎨","🔧","📱","🧪","📊","✍️","🎯","🌐","🎓","💡","🏗️","🎵","🛒"]

    init(project: Project?, onSave: @escaping (String, String) -> Void, onCancel: @escaping () -> Void) {
        _name  = State(initialValue: project?.name  ?? "")
        _emoji = State(initialValue: project?.emoji ?? "💼")
        isNew  = project == nil
        self.onSave = onSave; self.onCancel = onCancel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.secondary.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Text(emoji.isEmpty ? "💼" : emoji)
                        .font(.system(size: 24))
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("PROJEKTNAME").font(.system(size: 10, weight: .semibold)).foregroundStyle(.secondary)
                    TextField("z.B. App-Entwicklung, Marketing…", text: $name)
                        .textFieldStyle(.roundedBorder).font(.system(size: 13))
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(quickEmojis, id: \.self) { e in
                        Button(action: { emoji = e }) {
                            Text(e).font(.system(size: 18))
                                .frame(width: 32, height: 32)
                                .background(emoji == e ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }.buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 10)

            Divider()

            HStack {
                Button("Abbrechen", action: onCancel)
                    .buttonStyle(.plain).foregroundStyle(.secondary)
                Spacer()
                Button(isNew ? "Anlegen" : "Speichern") { onSave(name, emoji) }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }
}
