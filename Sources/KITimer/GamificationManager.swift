import Foundation
import EventKit
import Combine

struct ActivityStat: Codable, Identifiable {
    var title: String
    var count: Int
    var totalMinutes: Int
    var xpPerHour: Int = 100

    var id: String { title }

    var earnedXP: Int {
        Int(Double(totalMinutes) / 60.0 * Double(xpPerHour))
    }
    var activityLevel: Int {
        min(20, GamificationManager.level(forXP: earnedXP))
    }
    var activityProgress: Double {
        if activityLevel >= 20 { return 1.0 }
        return GamificationManager.levelProgress(forXP: earnedXP)
    }

    var formattedTime: String {
        let h = totalMinutes / 60; let m = totalMinutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
    var totalHours: Double { Double(totalMinutes) / 60.0 }
}

class GamificationManager: ObservableObject {
    @Published var activities: [ActivityStat] = []
    @Published var blacklist: Set<String>     = []
    @Published var streak: Int = 0

    @Published var minimumOccurrences: Int = 1 {
        didSet {
            UserDefaults.standard.set(minimumOccurrences, forKey: "gamMinOccurrences")
            refresh()
        }
    }

    @Published var excludedCalendarIDs: Set<String> = [] {
        didSet { saveExcludedCalendars(); refresh() }
    }

    @Published var historyStartDate: Date = Calendar.current.dateInterval(of: .year, for: Date())?.start ?? Date() {
        didSet {
            UserDefaults.standard.set(historyStartDate.timeIntervalSince1970, forKey: "gamHistoryStart")
            refresh()
        }
    }

    // Minuten pro Tag und Aktivität (nur bis jetzt gelaufene Zeit), Grundlage für Tages-/Wochen-/Monats-XP
    @Published var dayMinutes: [Date: [String: Int]] = [:]

    @Published var goalAuto: Bool = false {
        didSet { UserDefaults.standard.set(goalAuto, forKey: "gamGoalAuto") }
    }
    @Published var goalManualXP: Int = 500 {   // intern, 500 = 5 XP
        didSet { UserDefaults.standard.set(goalManualXP, forKey: "gamGoalManual") }
    }

    private var recognizedTitles: Set<String> = []
    private var xpPerHourMap: [String: Int]   = [:]
    private var storeObserver: AnyCancellable?
    private var accessObserver: AnyCancellable?
    private var refreshTimer: AnyCancellable?

    var totalXP: Int        { activities.reduce(0) { $0 + $1.earnedXP } }

    // MARK: - Tages-, Wochen-, Monats-XP und Tagesziel

    private func xp(on day: Date, rates: [String: Int]) -> Int {
        guard let perTitle = dayMinutes[Calendar.current.startOfDay(for: day)] else { return 0 }
        let total = perTitle.reduce(0.0) { acc, entry in
            guard let rate = rates[entry.key] else { return acc }
            return acc + Double(entry.value) / 60.0 * Double(rate)
        }
        return Int(total)
    }

    private var xpRates: [String: Int] {
        Dictionary(activities.map { ($0.title, $0.xpPerHour) }, uniquingKeysWith: { first, _ in first })
    }

    private func xp(in interval: DateInterval?) -> Int {
        guard let interval else { return 0 }
        let rates = xpRates
        return dayMinutes.keys
            .filter { interval.contains($0) }
            .reduce(0) { $0 + xp(on: $1, rates: rates) }
    }

    // Intern wird in kleinen Einheiten gerechnet (100 = 1 angezeigtes XP), damit gespeicherte Werte gültig bleiben
    static let xpDisplayDivisor = 100.0

    static func xpText(_ raw: Int) -> String {
        let v = Double(raw) / xpDisplayDivisor
        return v.formatted(.number.precision(.fractionLength(0...(abs(v) < 10 ? 1 : 0))))
    }

    var todayXP: Int { xp(on: Date(), rates: xpRates) }
    var weekXP:  Int { xp(in: Calendar.current.dateInterval(of: .weekOfYear, for: Date())) }
    var monthXP: Int { xp(in: Calendar.current.dateInterval(of: .month, for: Date())) }

    // Automatisch: Schnitt der letzten 7 Tage (nur Tage ab Startdatum) × 1,2, auf 0,5 XP gerundet, mindestens 1 XP
    var dailyGoal: Int {
        if !goalAuto { return goalManualXP }
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        let first = cal.startOfDay(for: historyStartDate)
        let days  = (1...7)
            .compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
            .filter { $0 >= first }
        guard !days.isEmpty else { return 100 }
        let rates = xpRates
        let avg = Double(days.reduce(0) { $0 + xp(on: $1, rates: rates) }) / Double(days.count)
        return max(100, Int((avg * 1.2 / 50).rounded(.up)) * 50)
    }

    var dailyGoalProgress: Double {
        min(1, Double(todayXP) / Double(max(dailyGoal, 1)))
    }
    var dailyGoalReached: Bool { todayXP >= dailyGoal }
    var overallLevel: Int   { Self.level(forXP: totalXP) }      // unbegrenzt
    var overallProgress: Double { Self.levelProgress(forXP: totalXP) }
    var rank: RankInfo      { Self.rankInfo(forLevel: overallLevel) }

    // MARK: - XP-Formel (exponentiell: 500 × 1,25^(N-1) pro Stufe)

    static func xpNeeded(toReach level: Int) -> Int {
        guard level > 1 else { return 0 }
        return (1..<level).reduce(0) { acc, n in
            acc + Int(500.0 * pow(1.25, Double(n - 1)))
        }
    }

    // Unbegrenzt – kein Cap
    static func level(forXP xp: Int) -> Int {
        var lv = 1
        while xpNeeded(toReach: lv + 1) <= xp { lv += 1 }
        return lv
    }

    static func levelProgress(forXP xp: Int) -> Double {
        let lv = level(forXP: xp)
        let current = xpNeeded(toReach: lv)
        let next    = xpNeeded(toReach: lv + 1)
        guard next > current else { return 0 }
        return min(1.0, Double(xp - current) / Double(next - current))
    }

    // MARK: - Rangsystem: Bronze I-IV → Silber → Gold → Platin → Diamant (je 4 Level)

    struct RankInfo {
        let name: String          // "Bronze", "Silber", "Gold", "Platin", "Diamant"
        let roman: String         // "I", "II", "III", "IV" (oder "★" für Lvl > 20)
        let nextRankLevel: Int?   // Level, ab dem nächster Rang beginnt
    }

    static func rankInfo(forLevel level: Int) -> RankInfo {
        let r = ["I", "II", "III", "IV"]
        switch level {
        case 1...4:   return RankInfo(name: "Bronze",  roman: r[level - 1],  nextRankLevel: 5)
        case 5...8:   return RankInfo(name: "Silber",  roman: r[level - 5],  nextRankLevel: 9)
        case 9...12:  return RankInfo(name: "Gold",    roman: r[level - 9],  nextRankLevel: 13)
        case 13...16: return RankInfo(name: "Platin",  roman: r[level - 13], nextRankLevel: 17)
        case 17...20: return RankInfo(name: "Diamant", roman: r[level - 17], nextRankLevel: nil)
        default:      return RankInfo(name: "Diamant", roman: "★",           nextRankLevel: nil)
        }
    }

    // MARK: - Init

    init() {
        load()
        refresh()
        // Datenänderungen (Events hinzugefügt/gelöscht)
        storeObserver = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }

        // Zugriffserteilung durch Nutzer
        accessObserver = NotificationCenter.default
            .publisher(for: .calendarAccessGranted)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }

        // Laufende Termine wachsen im Lauf des Tages, Tageswechsel neu berechnen
        refreshTimer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
    }

    // MARK: - Refresh

    func refresh() {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else { return }
        let minOcc       = minimumOccurrences
        let bl           = blacklist
        let known        = recognizedTitles
        let xpMap        = xpPerHourMap
        let excludedCals = excludedCalendarIDs
        let startDate    = historyStartDate
        DispatchQueue.global(qos: .userInitiated).async {
            self.fetchAndProcess(minOcc: minOcc, blacklist: bl, known: known,
                                  xpMap: xpMap, excludedCals: excludedCals, startDate: startDate)
        }
    }

    private func fetchAndProcess(minOcc: Int, blacklist: Set<String>,
                                  known: Set<String>, xpMap: [String: Int],
                                  excludedCals: Set<String>, startDate: Date) {
        // Frischer Store pro Abruf — vermeidet Probleme mit vor Zugriffserteilung erstellten Instanzen
        let store = EKEventStore()
        let end   = Date()
        let pred  = store.predicateForEvents(withStart: startDate, end: end, calendars: nil)
        let events = store.events(matching: pred).filter { !$0.isAllDay }

        var titleMap: [String: (count: Int, mins: Int)] = [:]
        var dayMin: [Date: [String: Int]] = [:]
        let cal = Calendar.current
        for event in events {
            if excludedCals.contains(event.calendar.calendarIdentifier) { continue }
            guard let raw = event.title else { continue }
            let title = raw.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty, !blacklist.contains(title) else { continue }
            let mins = max(0, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
            let ex = titleMap[title] ?? (0, 0)
            titleMap[title] = (ex.count + 1, ex.mins + mins)

            let elapsed = min(event.endDate, end).timeIntervalSince(event.startDate)
            if elapsed > 0 {
                let day = cal.startOfDay(for: event.startDate)
                dayMin[day, default: [:]][title, default: 0] += Int(elapsed / 60)
            }
        }

        var newRecognized = known
        for (title, data) in titleMap where data.count >= minOcc {
            newRecognized.insert(title)
        }

        var stats: [ActivityStat] = []
        for title in newRecognized {
            guard !blacklist.contains(title) else { continue }
            let data = titleMap[title] ?? (0, 0)
            let xph  = xpMap[title] ?? 100
            stats.append(ActivityStat(title: title, count: data.count,
                                       totalMinutes: data.mins, xpPerHour: xph))
        }
        stats.sort { $0.count > $1.count }

        let streak = Self.calcStreak(from: events)

        DispatchQueue.main.async {
            self.recognizedTitles = newRecognized
            self.activities = stats
            self.dayMinutes = dayMin
            self.streak     = streak
            self.save()
        }
    }

    // MARK: - Blacklist

    func addToBlacklist(_ title: String) {
        blacklist.insert(title)
        recognizedTitles.remove(title)
        activities.removeAll { $0.title == title }
        saveBlacklist(); saveRecognized()
    }

    func removeFromBlacklist(_ title: String) {
        blacklist.remove(title)
        saveBlacklist()
        refresh()
    }

    // MARK: - Umbenennen & Zusammenlegen

    func renameActivity(from old: String, to new: String) {
        let trimmed = new.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed != old else { return }
        if recognizedTitles.contains(trimmed) {
            mergeActivities(sources: [old], into: trimmed)
        } else {
            recognizedTitles.remove(old)
            recognizedTitles.insert(trimmed)
            if let xph = xpPerHourMap.removeValue(forKey: old) {
                xpPerHourMap[trimmed] = xph
            }
            if let i = activities.firstIndex(where: { $0.title == old }) {
                activities[i].title = trimmed
            }
            saveXPMap(); saveRecognized(); save()
        }
    }

    func mergeActivities(sources: [String], into target: String) {
        var addCount = 0, addMins = 0
        for title in sources where title != target {
            if let act = activities.first(where: { $0.title == title }) {
                addCount += act.count
                addMins  += act.totalMinutes
            }
            recognizedTitles.remove(title)
            xpPerHourMap.removeValue(forKey: title)
        }
        recognizedTitles.insert(target)
        if let i = activities.firstIndex(where: { $0.title == target }) {
            activities[i].count        += addCount
            activities[i].totalMinutes += addMins
        }
        activities.removeAll { sources.contains($0.title) && $0.title != target }
        activities.sort { $0.count > $1.count }
        saveXPMap(); saveRecognized(); save()
    }

    // MARK: - XP/h pro Aktivität

    func setXPPerHour(_ xph: Int, for title: String) {
        xpPerHourMap[title] = xph
        if let i = activities.firstIndex(where: { $0.title == title }) {
            activities[i].xpPerHour = xph
        }
        saveXPMap()
    }

    // MARK: - Streak

    private static func calcStreak(from events: [EKEvent]) -> Int {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: Date())
        var days  = Set<Date>()
        for e in events { days.insert(cal.startOfDay(for: e.startDate)) }
        var streak = 0; var check = today
        while days.contains(check) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: check) else { break }
            check = prev
        }
        return streak
    }

    // MARK: - Persistenz

    private func save() {
        if let d = try? JSONEncoder().encode(activities) {
            UserDefaults.standard.set(d, forKey: "gamActivities")
        }
        UserDefaults.standard.set(streak, forKey: "gamStreak")
        saveRecognized()
    }

    private func saveRecognized() {
        if let d = try? JSONEncoder().encode(Array(recognizedTitles)) {
            UserDefaults.standard.set(d, forKey: "gamRecognized")
        }
    }

    private func saveBlacklist() {
        if let d = try? JSONEncoder().encode(Array(blacklist)) {
            UserDefaults.standard.set(d, forKey: "gamBlacklist")
        }
    }

    private func saveExcludedCalendars() {
        if let d = try? JSONEncoder().encode(Array(excludedCalendarIDs)) {
            UserDefaults.standard.set(d, forKey: "gamExcludedCals")
        }
    }

    private func saveXPMap() {
        if let d = try? JSONEncoder().encode(xpPerHourMap) {
            UserDefaults.standard.set(d, forKey: "gamXPMap")
        }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: "gamActivities"),
           let list = try? JSONDecoder().decode([ActivityStat].self, from: d) { activities = list }
        if let d = UserDefaults.standard.data(forKey: "gamRecognized"),
           let list = try? JSONDecoder().decode([String].self, from: d) { recognizedTitles = Set(list) }
        if let d = UserDefaults.standard.data(forKey: "gamBlacklist"),
           let list = try? JSONDecoder().decode([String].self, from: d) { blacklist = Set(list) }
        if let d = UserDefaults.standard.data(forKey: "gamXPMap"),
           let map  = try? JSONDecoder().decode([String: Int].self, from: d) { xpPerHourMap = map }
        if let d = UserDefaults.standard.data(forKey: "gamExcludedCals"),
           let list = try? JSONDecoder().decode([String].self, from: d) { excludedCalendarIDs = Set(list) }
        let stored = UserDefaults.standard.integer(forKey: "gamMinOccurrences")
        minimumOccurrences = stored >= 1 ? stored : 1
        streak = UserDefaults.standard.integer(forKey: "gamStreak")
        if UserDefaults.standard.object(forKey: "gamGoalAuto") != nil {
            goalAuto = UserDefaults.standard.bool(forKey: "gamGoalAuto")
        }
        let manual = UserDefaults.standard.integer(forKey: "gamGoalManual")
        if manual > 0 { goalManualXP = manual }
        // Einmalig: Tagesziel auf festen Standard von 5 XP setzen
        if !UserDefaults.standard.bool(forKey: "gamGoalDefault5") {
            goalAuto = false
            goalManualXP = 500
            UserDefaults.standard.set(true, forKey: "gamGoalDefault5")
        }
        let ts = UserDefaults.standard.double(forKey: "gamHistoryStart")
        if ts > 0 { historyStartDate = Date(timeIntervalSince1970: ts) }
        // sonst bleibt der Default (Jahresanfang) erhalten
    }
}
