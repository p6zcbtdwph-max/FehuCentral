import Foundation

struct TimerInterval: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Neues Intervall"
    var startHour: Int = 9
    var startMinute: Int = 0
    var endHour: Int = 11
    var endMinute: Int = 0

    var startTotalMinutes: Int { startHour * 60 + startMinute }
    var endTotalMinutes:   Int { endHour   * 60 + endMinute   }
    var durationMinutes:   Int { max(0, endTotalMinutes - startTotalMinutes) }

    var displayRange: String {
        String(format: "%02d:%02d – %02d:%02d", startHour, startMinute, endHour, endMinute)
    }

    var durationText: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        if h > 0 && m > 0 { return "\(h)h \(m)m" }
        if h > 0 { return "\(h)h" }
        return "\(m)m"
    }
}
