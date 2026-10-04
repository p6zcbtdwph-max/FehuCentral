import Foundation
import SwiftUI
import Combine

/// Wochenlimit (Reset alle 7 Tage) und Sitzungsfenster (z. B. 5 h) für KI-Nutzung.
final class AICycleManager: ObservableObject {
    private let d = UserDefaults.standard

    @Published var enabled = false {
        didSet { d.set(enabled, forKey: "aiEnabled") }
    }
    /// Ein beliebiger Reset-Zeitpunkt; die Woche wiederholt sich von hier aus alle 7 Tage.
    @Published var weeklyAnchor = Date() {
        didSet { d.set(weeklyAnchor.timeIntervalSince1970, forKey: "aiWeeklyAnchor") }
    }
    @Published var usedPercent = 0.0 {
        didSet { d.set(usedPercent, forKey: "aiUsedPercent") }
    }
    @Published var usageEnteredAt = Date.distantPast {
        didSet { d.set(usageEnteredAt.timeIntervalSince1970, forKey: "aiUsageEnteredAt") }
    }
    @Published var sessionEnd: Date? = nil {
        didSet { d.set(sessionEnd?.timeIntervalSince1970 ?? 0, forKey: "aiSessionEnd") }
    }
    @Published var sessionHours = 5 {
        didSet { d.set(sessionHours, forKey: "aiSessionHours") }
    }
    @Published var showSessionOnMain = true {
        didSet { d.set(showSessionOnMain, forKey: "aiShowSession") }
    }
    @Published private(set) var now = Date()

    private var timer: AnyCancellable?
    private var cal: Calendar { .current }

    init() {
        if d.object(forKey: "aiEnabled") != nil { enabled = d.bool(forKey: "aiEnabled") }
        let anchor = d.double(forKey: "aiWeeklyAnchor")
        if anchor > 0 { weeklyAnchor = Date(timeIntervalSince1970: anchor) }
        usedPercent = d.double(forKey: "aiUsedPercent")
        let entered = d.double(forKey: "aiUsageEnteredAt")
        if entered > 0 { usageEnteredAt = Date(timeIntervalSince1970: entered) }
        let end = d.double(forKey: "aiSessionEnd")
        if end > 0 { sessionEnd = Date(timeIntervalSince1970: end) }
        let hours = d.integer(forKey: "aiSessionHours")
        if hours > 0 { sessionHours = hours }
        if d.object(forKey: "aiShowSession") != nil { showSessionOnMain = d.bool(forKey: "aiShowSession") }

        timer = Timer.publish(every: 20, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.now = Date() }
    }

    // MARK: - Wochenlimit

    private func weekDate(_ k: Int) -> Date {
        cal.date(byAdding: .day, value: 7 * k, to: weeklyAnchor) ?? weeklyAnchor.addingTimeInterval(Double(k) * 7 * 86400)
    }

    /// Letzter Reset vor jetzt.
    var weekStart: Date {
        var k = Int(floor(now.timeIntervalSince(weeklyAnchor) / (7 * 86400)))
        while weekDate(k) > now { k -= 1 }
        while weekDate(k + 1) <= now { k += 1 }
        return weekDate(k)
    }

    /// Nächster Reset.
    var weekEnd: Date { cal.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart.addingTimeInterval(7 * 86400) }

    /// Anteil der Woche, der verstrichen ist (0 bis 1), nach Uhrzeit.
    var weekElapsed: Double {
        let total = weekEnd.timeIntervalSince(weekStart)
        guard total > 0 else { return 0 }
        return min(1, max(0, now.timeIntervalSince(weekStart) / total))
    }

    var perDayPercent: Double { 100.0 / 7.0 }
    var targetPercent: Double { weekElapsed * 100 }

    /// Eingetragener Verbrauch; vor dem letzten Reset eingetragene Werte zählen nicht mehr.
    var usedNow: Double { usageEnteredAt >= weekStart ? usedPercent : 0 }
    var freePercent: Double { max(0, 100 - usedNow) }

    /// Positiv: über Plan, negativ: unter Plan.
    var diffPercent: Double { usedNow - targetPercent }

    /// 0 bis 6
    var dayIndex: Int { min(6, Int(weekElapsed * 7)) }

    func dayStart(_ i: Int) -> Date {
        cal.date(byAdding: .day, value: i, to: weekStart) ?? weekStart.addingTimeInterval(Double(i) * 86400)
    }

    var dayEnd: Date { dayStart(dayIndex + 1) }

    /// Was bis zum Ende des laufenden Tages (ab Reset-Uhrzeit gezählt) noch erlaubt ist; negativ = Budget überschritten.
    var todayAllowanceLeft: Double { Double(dayIndex + 1) * perDayPercent - usedNow }

    func setUsed(_ value: Double) {
        usedPercent = min(100, max(0, value))
        usageEnteredAt = Date()
    }

    var statusText: String {
        let diff = diffPercent
        if abs(diff) < 0.5 { return "Genau im Plan" }
        return diff < 0 ? "\(Self.pct(-diff)) unter Plan" : "\(Self.pct(diff)) über Plan"
    }

    var statusColor: Color {
        let diff = diffPercent
        if diff <= 0.5 { return .green }
        return diff <= perDayPercent / 2 ? .orange : .red
    }

    static func pct(_ v: Double) -> String {
        v.formatted(.number.precision(.fractionLength(0...1))) + "%"
    }

    // MARK: - Sitzung

    var sessionLength: TimeInterval { Double(sessionHours) * 3600 }
    var sessionActive: Bool { (sessionEnd ?? .distantPast) > now }
    var sessionRemaining: TimeInterval { max(0, (sessionEnd ?? now).timeIntervalSince(now)) }

    /// Anteil des Sitzungsfensters, der verstrichen ist.
    var sessionProgress: Double {
        guard sessionActive else { return 0 }
        return min(1, max(0, 1 - sessionRemaining / sessionLength))
    }

    var sessionRemainingText: String {
        let minutes = Int((sessionRemaining / 60).rounded(.up))
        let h = minutes / 60, m = minutes % 60
        if h > 0 { return m > 0 ? "\(h) h \(m) min" : "\(h) h" }
        return "\(m) min"
    }

    func startSession() {
        now = Date()
        sessionEnd = now.addingTimeInterval(sessionLength)
    }

    func endSession() { sessionEnd = nil }

    /// Setzt das Sitzungsende auf die nächste Uhrzeit, die der übergebenen entspricht.
    func setSessionReset(toClockOf time: Date) {
        let comps = cal.dateComponents([.hour, .minute], from: time)
        sessionEnd = cal.nextDate(after: Date(), matching: comps, matchingPolicy: .nextTime)
    }
}
