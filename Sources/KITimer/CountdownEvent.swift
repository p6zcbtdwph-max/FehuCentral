import Foundation

struct CountdownEvent: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String = "Neues Datum"
    var date: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()

    func daysRemaining(from today: Date = Date()) -> Int {
        let cal = Calendar.current
        let start = cal.startOfDay(for: today)
        let end   = cal.startOfDay(for: date)
        return cal.dateComponents([.day], from: start, to: end).day ?? 0
    }

    var displayDate: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        f.locale = Locale(identifier: "de_DE")
        return f.string(from: date)
    }
}
