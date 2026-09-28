import Foundation
import Combine
import SwiftUI
import UserNotifications

class TimeManager: ObservableObject {
    @Published var now: Date = Date()

    // MARK: - Tag-Einstellungen
    var startHour: Int {
        get { UserDefaults.standard.object(forKey: "startHour") as? Int ?? 8 }
        set { UserDefaults.standard.set(newValue, forKey: "startHour"); objectWillChange.send() }
    }
    var endHour: Int {
        get { UserDefaults.standard.object(forKey: "endHour") as? Int ?? 22 }
        set { UserDefaults.standard.set(newValue, forKey: "endHour"); objectWillChange.send() }
    }
    var weekendEnabled: Bool {
        get { UserDefaults.standard.object(forKey: "weekendEnabled") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "weekendEnabled"); objectWillChange.send() }
    }
    var weekendStartHour: Int {
        get { UserDefaults.standard.object(forKey: "weekendStartHour") as? Int ?? 10 }
        set { UserDefaults.standard.set(newValue, forKey: "weekendStartHour"); objectWillChange.send() }
    }
    var weekendEndHour: Int {
        get { UserDefaults.standard.object(forKey: "weekendEndHour") as? Int ?? 22 }
        set { UserDefaults.standard.set(newValue, forKey: "weekendEndHour"); objectWillChange.send() }
    }

    // MARK: - Benachrichtigungen
    var notify2h: Bool {
        get { UserDefaults.standard.object(forKey: "notify2h") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notify2h"); objectWillChange.send() }
    }
    var notify1h: Bool {
        get { UserDefaults.standard.object(forKey: "notify1h") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notify1h"); objectWillChange.send() }
    }
    var notify30m: Bool {
        get { UserDefaults.standard.object(forKey: "notify30m") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "notify30m"); objectWillChange.send() }
    }

    // MARK: - Pomodoro-Einstellungen
    var pomodoroDuration: Int {
        get { UserDefaults.standard.object(forKey: "pomodoroDuration") as? Int ?? 25 }
        set { UserDefaults.standard.set(newValue, forKey: "pomodoroDuration"); objectWillChange.send() }
    }
    var pomodoroRestDuration: Int {
        get { UserDefaults.standard.object(forKey: "pomodoroRestDuration") as? Int ?? 5 }
        set { UserDefaults.standard.set(newValue, forKey: "pomodoroRestDuration"); objectWillChange.send() }
    }

    // MARK: - Pomodoro Zustand
    enum PomodoroPhase: Equatable { case idle, work, rest }

    @Published var pomodoroPhase: PomodoroPhase = .idle
    @Published var pomodoroRemaining: TimeInterval = 0
    @Published var pomodoroRunning: Bool = false
    private var pomodoroTick: AnyCancellable?

    // MARK: - Intervalle
    enum IntervalStatus { case upcoming, active, done }

    var intervals: [TimerInterval] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "intervals"),
                  let list = try? JSONDecoder().decode([TimerInterval].self, from: data)
            else { return [] }
            return list.sorted { $0.startTotalMinutes < $1.startTotalMinutes }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "intervals")
                objectWillChange.send()
            }
        }
    }

    // MARK: - Countdowns
    var countdowns: [CountdownEvent] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "countdowns"),
                  let list = try? JSONDecoder().decode([CountdownEvent].self, from: data)
            else { return [] }
            return list.sorted { $0.date < $1.date }
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "countdowns")
                objectWillChange.send()
            }
        }
    }

    func addCountdown(_ event: CountdownEvent) {
        var list = countdowns
        list.append(event)
        countdowns = list
    }

    func updateCountdown(_ event: CountdownEvent) {
        var list = countdowns
        if let i = list.firstIndex(where: { $0.id == event.id }) { list[i] = event }
        countdowns = list
    }

    func deleteCountdown(id: UUID) {
        countdowns = countdowns.filter { $0.id != id }
    }

    // nächstes Countdown-Event in der Zukunft (für Banner auf Hauptseite)
    var nextCountdown: CountdownEvent? {
        countdowns.first { $0.daysRemaining() >= 0 }
    }

    // MARK: - Timer
    private var mainTick: AnyCancellable?
    private let notifCenter = UNUserNotificationCenter.current()

    init() {
        requestNotificationPermission()
        mainTick = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in
                self?.now = date
                self?.checkNotifications()
            }
    }

    // MARK: - Zeitberechnung
    private var calendar: Calendar { Calendar.current }

    private var isWeekend: Bool {
        let wd = calendar.component(.weekday, from: now)
        return wd == 1 || wd == 7
    }

    var effectiveStartHour: Int { (weekendEnabled && isWeekend) ? weekendStartHour : startHour }
    var effectiveEndHour:   Int { (weekendEnabled && isWeekend) ? weekendEndHour   : endHour   }

    var dayStart: Date { calendar.date(bySettingHour: effectiveStartHour, minute: 0, second: 0, of: now)! }
    var dayEnd:   Date { calendar.date(bySettingHour: effectiveEndHour,   minute: 0, second: 0, of: now)! }

    // MARK: - Tag
    var dayProgress: Double {
        let total   = dayEnd.timeIntervalSince(dayStart)
        let elapsed = now.timeIntervalSince(dayStart)
        return max(0, min(1, elapsed / total))
    }
    var dayRemainingSeconds: TimeInterval { max(0, dayEnd.timeIntervalSince(now)) }
    var dayRemainingText: String {
        let s = dayRemainingSeconds
        if s <= 0 { return "Tag beendet" }
        let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
        return h > 0 ? "\(h)h \(m)m verbleibend" : "\(m)m verbleibend"
    }

    // MARK: - Woche
    var weekProgress: Double {
        let s = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let e = calendar.date(byAdding: .weekOfYear, value: 1, to: s)!
        return max(0, min(1, now.timeIntervalSince(s) / e.timeIntervalSince(s)))
    }
    var weekRemainingText: String {
        let s = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        let e = calendar.date(byAdding: .weekOfYear, value: 1, to: s)!
        let days = calendar.dateComponents([.day], from: now, to: e).day ?? 0
        if days == 0 { return "\(calendar.dateComponents([.hour], from: now, to: e).hour ?? 0)h verbleibend" }
        return "\(days) \(days == 1 ? "Tag" : "Tage") verbleibend"
    }

    // MARK: - Monat
    var monthProgress: Double {
        let s = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let e = calendar.date(byAdding: .month, value: 1, to: s)!
        return max(0, min(1, now.timeIntervalSince(s) / e.timeIntervalSince(s)))
    }
    var monthRemainingText: String {
        let s = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let e = calendar.date(byAdding: .month, value: 1, to: s)!
        let d = calendar.dateComponents([.day], from: now, to: e).day ?? 0
        return "\(d) \(d == 1 ? "Tag" : "Tage") verbleibend"
    }

    // MARK: - Jahr
    var yearProgress: Double {
        let s = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let e = calendar.date(byAdding: .year, value: 1, to: s)!
        return max(0, min(1, now.timeIntervalSince(s) / e.timeIntervalSince(s)))
    }
    var yearRemainingText: String {
        let s = calendar.date(from: calendar.dateComponents([.year], from: now))!
        let e = calendar.date(byAdding: .year, value: 1, to: s)!
        let d = calendar.dateComponents([.day], from: now, to: e).day ?? 0
        return "\(d) Tage verbleibend"
    }

    // MARK: - Menüleiste
    var menuBarText: String {
        var parts: [String] = []

        // Pomodoro (zuerst, wenn aktiv)
        if pomodoroPhase != .idle {
            let icon = pomodoroPhase == .rest ? "☕" : "🍅"
            parts.append("\(icon) \(pomodoroDisplayText)")
        }

        // Tages-Countdown (immer)
        let s = dayRemainingSeconds
        if s > 0 {
            let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60
            parts.append(h > 0 ? "\(h)h\(String(format: "%02d", m))" : "\(m)m")
        } else {
            parts.append("✓")
        }

        // Aktives Intervall
        if let iv = activeInterval {
            let rem = iv.endTotalMinutes - currentDayMinutes
            if rem > 0 {
                let h = rem / 60; let m = rem % 60
                let t = h > 0 ? "\(h)h\(m > 0 ? String(format: "%02d", m) : "")m" : "\(m)m"
                parts.append(t)
            }
        }

        return parts.joined(separator: " · ")
    }

    var menuBarIcon: String {
        if pomodoroPhase == .work { return "timer" }
        switch dayProgress {
        case ..<0.5:  return "hourglass.bottomhalf.filled"
        case ..<0.85: return "hourglass"
        default:      return "hourglass.tophalf.filled"
        }
    }

    // MARK: - Pomodoro Methoden
    func startPomodoro() {
        pomodoroPhase = .work
        pomodoroRemaining = TimeInterval(pomodoroDuration * 60)
        pomodoroRunning = true
        startPomodoroTick()
    }

    func stopPomodoro() {
        pomodoroTick?.cancel()
        pomodoroPhase = .idle
        pomodoroRunning = false
        pomodoroRemaining = 0
    }

    func togglePomodoroRunning() {
        pomodoroRunning.toggle()
        if pomodoroRunning { startPomodoroTick() } else { pomodoroTick?.cancel() }
    }

    private func startPomodoroTick() {
        pomodoroTick?.cancel()
        pomodoroTick = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tickPomodoro() }
    }

    private func tickPomodoro() {
        guard pomodoroRunning else { return }
        pomodoroRemaining -= 1
        if pomodoroRemaining <= 0 {
            if pomodoroPhase == .work {
                scheduleNotification(id: "pt_pom_work", title: "🍅 Fokusphase geschafft!", body: "Mach eine \(pomodoroRestDuration)-minütige Pause.")
                pomodoroPhase = .rest
                pomodoroRemaining = TimeInterval(pomodoroRestDuration * 60)
            } else {
                scheduleNotification(id: "pt_pom_rest", title: "⚡ Pause beendet!", body: "Bereit für die nächste Fokusphase?")
                stopPomodoro()
            }
        }
    }

    var pomodoroDisplayText: String {
        let m = Int(pomodoroRemaining) / 60
        let s = Int(pomodoroRemaining) % 60
        return String(format: "%02d:%02d", m, s)
    }

    var pomodoroProgress: Double {
        guard pomodoroPhase != .idle else { return 0 }
        let total = TimeInterval((pomodoroPhase == .work ? pomodoroDuration : pomodoroRestDuration) * 60)
        guard total > 0 else { return 0 }
        return 1.0 - (pomodoroRemaining / total)
    }

    // MARK: - Intervall Methoden
    private var currentDayMinutes: Int {
        calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
    }

    var activeInterval: TimerInterval? {
        let m = currentDayMinutes
        return intervals.first { $0.startTotalMinutes <= m && m < $0.endTotalMinutes }
    }

    func intervalStatus(_ iv: TimerInterval) -> IntervalStatus {
        let m = currentDayMinutes
        if m >= iv.endTotalMinutes   { return .done }
        if m >= iv.startTotalMinutes { return .active }
        return .upcoming
    }

    func intervalProgress(_ iv: TimerInterval) -> Double {
        let elapsed = currentDayMinutes - iv.startTotalMinutes
        guard iv.durationMinutes > 0 else { return 0 }
        return max(0, min(1, Double(elapsed) / Double(iv.durationMinutes)))
    }

    func intervalRemainingText(_ iv: TimerInterval) -> String {
        let rem = iv.endTotalMinutes - currentDayMinutes
        guard rem > 0 else { return "Beendet" }
        let h = rem / 60; let m = rem % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m verbleibend" }
        if h > 0 { return "\(h)h verbleibend" }
        return "\(m)m verbleibend"
    }

    func addInterval(_ iv: TimerInterval) {
        var list = intervals; list.append(iv); intervals = list
    }
    func deleteInterval(id: UUID) {
        intervals = intervals.filter { $0.id != id }
    }
    func updateInterval(_ iv: TimerInterval) {
        var list = intervals
        if let i = list.firstIndex(where: { $0.id == iv.id }) { list[i] = iv }
        intervals = list
    }

    // MARK: - Benachrichtigungen
    private func requestNotificationPermission() {
        notifCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return "firedNotifs_\(f.string(from: now))"
    }

    private func checkNotifications() {
        let remaining = dayRemainingSeconds
        guard remaining > 0 else { return }
        let key = todayKey()
        var fired = Set(UserDefaults.standard.stringArray(forKey: key) ?? [])
        let thresholds: [(TimeInterval, String, Bool, String, String)] = [
            (7200, "2h",  notify2h,  "Noch 2 Stunden",   "Dein Tag endet um \(String(format: "%02d:00", effectiveEndHour)) Uhr."),
            (3600, "1h",  notify1h,  "Noch 1 Stunde",    "Zeit für die wichtigsten Aufgaben."),
            (1800, "30m", notify30m, "Noch 30 Minuten",  "Was willst du heute noch erledigen?"),
        ]
        var changed = false
        for (threshold, id, enabled, title, body) in thresholds {
            guard enabled, remaining <= threshold, !fired.contains(id) else { continue }
            scheduleNotification(id: "pt_\(id)", title: title, body: body)
            fired.insert(id); changed = true
        }
        if changed { UserDefaults.standard.set(Array(fired), forKey: key) }
    }

    func scheduleNotification(id: String, title: String, body: String) {
        let c = UNMutableNotificationContent()
        c.title = title; c.body = body; c.sound = .default
        notifCenter.add(UNNotificationRequest(identifier: id, content: c, trigger: nil))
    }
}
