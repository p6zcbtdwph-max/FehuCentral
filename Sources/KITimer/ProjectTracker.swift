import Foundation
import Combine

struct Project: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var emoji: String = "💼"
}

struct TimeEntry: Codable, Identifiable {
    var id: UUID = UUID()
    var projectId: UUID
    var startDate: Date
    var endDate: Date?

    var duration: TimeInterval { (endDate ?? Date()).timeIntervalSince(startDate) }
    var isRunning: Bool { endDate == nil }
}

class ProjectTracker: ObservableObject {
    @Published var projects: [Project] = []
    @Published var entries:  [TimeEntry] = []
    @Published var elapsed:  TimeInterval = 0   // live tick für laufenden Timer

    private var ticker: AnyCancellable?

    init() { load() }

    // MARK: - Aktiver Eintrag
    var activeEntry: TimeEntry? { entries.first { $0.isRunning } }
    var activeProject: Project? {
        guard let e = activeEntry else { return nil }
        return projects.first { $0.id == e.projectId }
    }

    func toggle(_ project: Project) {
        if let running = activeEntry {
            // laufenden stoppen
            if let i = entries.firstIndex(where: { $0.id == running.id }) {
                entries[i].endDate = Date()
            }
            // war es dasselbe Projekt → nur stoppen
            if running.projectId == project.id {
                saveEntries(); stopTick(); return
            }
        }
        // neuen Eintrag starten
        entries.append(TimeEntry(projectId: project.id, startDate: Date()))
        saveEntries()
        startTick()
    }

    func stopActive() {
        if let i = entries.firstIndex(where: { $0.endDate == nil }) {
            entries[i].endDate = Date()
            saveEntries()
        }
        stopTick()
    }

    // MARK: - Aggregation
    func todayDuration(for project: Project) -> TimeInterval {
        let start = Calendar.current.startOfDay(for: Date())
        return entries
            .filter { $0.projectId == project.id && $0.startDate >= start }
            .reduce(0) { $0 + $1.duration }
    }

    func weekDuration(for project: Project) -> TimeInterval {
        let cal   = Calendar.current
        let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        return entries
            .filter { $0.projectId == project.id && $0.startDate >= start }
            .reduce(0) { $0 + $1.duration }
    }

    var totalTodayDuration: TimeInterval {
        let start = Calendar.current.startOfDay(for: Date())
        return entries.filter { $0.startDate >= start }.reduce(0) { $0 + $1.duration }
    }

    // MARK: - Projekte verwalten
    func addProject(name: String, emoji: String) {
        projects.append(Project(name: name, emoji: emoji))
        saveProjects()
    }

    func deleteProject(id: UUID) {
        projects.removeAll { $0.id == id }
        entries.removeAll { $0.projectId == id }
        saveProjects(); saveEntries()
    }

    func updateProject(_ p: Project) {
        if let i = projects.firstIndex(where: { $0.id == p.id }) { projects[i] = p }
        saveProjects()
    }

    // MARK: - CSV-Export
    func exportCSV() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm"
        var lines = ["Datum,Start,Ende,Projekt,Dauer (min)"]
        for e in entries.sorted(by: { $0.startDate < $1.startDate }) {
            guard let end = e.endDate else { continue }
            let name = projects.first { $0.id == e.projectId }?.name ?? "Unbekannt"
            let mins = Int(e.duration / 60)
            lines.append("\(f.string(from: e.startDate)),\(f.string(from: e.startDate)),\(f.string(from: end)),\(name),\(mins)")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Live-Tick
    private func startTick() {
        elapsed = activeEntry.map { Date().timeIntervalSince($0.startDate) } ?? 0
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, let e = self.activeEntry else { return }
                self.elapsed = Date().timeIntervalSince(e.startDate)
            }
    }

    private func stopTick() { ticker?.cancel(); ticker = nil; elapsed = 0 }

    // MARK: - Persistenz
    private func load() {
        if let d = UserDefaults.standard.data(forKey: "ptProjects"),
           let list = try? JSONDecoder().decode([Project].self, from: d) { projects = list }
        if let d = UserDefaults.standard.data(forKey: "ptEntries"),
           let list = try? JSONDecoder().decode([TimeEntry].self, from: d) { entries = list }
        if activeEntry != nil { startTick() }
    }

    private func saveProjects() {
        if let d = try? JSONEncoder().encode(projects) { UserDefaults.standard.set(d, forKey: "ptProjects") }
    }

    private func saveEntries() {
        if let d = try? JSONEncoder().encode(entries) { UserDefaults.standard.set(d, forKey: "ptEntries") }
    }
}

// MARK: - Formatierung
extension TimeInterval {
    var hhmm: String {
        let total = Int(self)
        let h = total / 3600; let m = (total % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
    var hhmmss: String {
        let total = Int(self)
        let h = total / 3600; let m = (total % 3600) / 60; let s = total % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%02d:%02d", m, s)
    }
}
