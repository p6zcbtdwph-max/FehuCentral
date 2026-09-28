import Foundation
import EventKit

struct ActivityStat: Codable, Identifiable {
    var title: String
    var count: Int
    var totalMinutes: Int

    var id: String { title }
    var xp: Int { count * 10 }
    var formattedTime: String {
        let h = totalMinutes / 60; let m = totalMinutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}

class GamificationManager: ObservableObject {
    @Published var activities: [ActivityStat] = []
    @Published var totalXP: Int = 0
    @Published var streak: Int = 0

    private let store = EKEventStore()

    var level: Int { max(1, totalXP / 100) }
    var xpInLevel: Int { totalXP % 100 }
    var levelProgress: Double { Double(xpInLevel) / 100.0 }

    init() {
        load()
        refresh()
    }

    func refresh() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        DispatchQueue.global(qos: .userInitiated).async { self.fetchAndProcess() }
    }

    private func fetchAndProcess() {
        let end   = Date()
        let start = Calendar.current.date(byAdding: .weekOfYear, value: -12, to: end)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        let events = store.events(matching: pred).filter { !$0.isAllDay }

        var titleMap: [String: (count: Int, totalMins: Int)] = [:]
        for event in events {
            guard let raw = event.title, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
            let title = raw.trimmingCharacters(in: .whitespaces)
            let mins  = max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
            let ex = titleMap[title] ?? (0, 0)
            titleMap[title] = (ex.count + 1, ex.totalMins + mins)
        }

        let stats = titleMap
            .map { ActivityStat(title: $0.key, count: $0.value.count, totalMinutes: $0.value.totalMins) }
            .sorted { $0.count > $1.count }

        let xp     = stats.reduce(0) { $0 + $1.xp }
        let streak = Self.calcStreak(from: events)

        DispatchQueue.main.async {
            self.activities = stats
            self.totalXP    = xp
            self.streak     = streak
            self.save()
        }
    }

    private static func calcStreak(from events: [EKEvent]) -> Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days  = Set<Date>()
        for e in events {
            let d = cal.startOfDay(for: e.startDate)
            if d <= today { days.insert(d) }
        }
        var streak = 0
        var check  = today
        while days.contains(check) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    private func save() {
        if let d = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(d, forKey: "gamActivities")
        }
        UserDefaults.standard.set(totalXP, forKey: "gamXP")
        UserDefaults.standard.set(streak,  forKey: "gamStreak")
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: "gamActivities"),
           let list = try? JSONDecoder().decode([ActivityStat].self, from: d) {
            activities = list
        }
        totalXP = UserDefaults.standard.integer(forKey: "gamXP")
        streak  = UserDefaults.standard.integer(forKey: "gamStreak")
    }
}
