import EventKit
import Combine
import SwiftUI

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarColor: Color

    var startTotalMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: startDate)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    var endTotalMinutes: Int {
        let c = Calendar.current.dateComponents([.hour, .minute], from: endDate)
        return (c.hour ?? 0) * 60 + (c.minute ?? 0)
    }
    var durationMinutes: Int { max(0, endTotalMinutes - startTotalMinutes) }

    var timeRange: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return "\(f.string(from: startDate)) – \(f.string(from: endDate))"
    }

    var isActive: Bool {
        let now = Date()
        return now >= startDate && now < endDate
    }

    var progress: Double {
        guard isActive else { return 0 }
        let total = endDate.timeIntervalSince(startDate)
        let elapsed = Date().timeIntervalSince(startDate)
        return max(0, min(1, elapsed / total))
    }
}

class CalendarManager: ObservableObject {
    private let store = EKEventStore()
    @Published var todayEvents: [CalendarEvent] = []
    @Published var authStatus: EKAuthorizationStatus = .notDetermined

    private var refreshTimer: AnyCancellable?

    init() {
        authStatus = EKEventStore.authorizationStatus(for: .event)
        if authStatus == .fullAccess { fetchToday() }

        // alle 5 Minuten neu laden
        refreshTimer = Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.fetchToday() }
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.authStatus = EKEventStore.authorizationStatus(for: .event)
                if granted { self?.fetchToday() }
            }
        }
    }

    func fetchToday() {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let end   = cal.date(byAdding: .day, value: 1, to: start)!
        let pred  = store.predicateForEvents(withStart: start, end: end, calendars: nil)

        let events = store.events(matching: pred)
            .filter { !$0.isAllDay && $0.endDate > Date() - 3600 }
            .sorted { $0.startDate < $1.startDate }
            .map { ev -> CalendarEvent in
                let cgColor = ev.calendar.cgColor
                let color   = cgColor.map { Color(cgColor: $0) } ?? .blue
                return CalendarEvent(
                    id: ev.eventIdentifier ?? UUID().uuidString,
                    title: ev.title ?? "Termin",
                    startDate: ev.startDate,
                    endDate: ev.endDate,
                    calendarColor: color
                )
            }

        DispatchQueue.main.async { self.todayEvents = events }
    }

    var activeEvent: CalendarEvent? { todayEvents.first { $0.isActive } }
    var nextEvent:   CalendarEvent? { todayEvents.first { $0.startDate > Date() } }
}
