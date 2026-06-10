import AppKit
import Combine

struct ClipboardEntry: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var label: String?          // optionaler Name für manuell angelegte Snippets
    var date: Date = Date()

    var displayTitle: String {
        if let l = label, !l.trimmingCharacters(in: .whitespaces).isEmpty { return l }
        return shortPreview
    }

    var preview: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "(leer)" : trimmed
    }

    var shortPreview: String {
        let p = preview
        return p.count > 80 ? String(p.prefix(80)) + "…" : p
    }
}

// Pasteboard-Typen die Passwort-Manager setzen um Clipboard-Tools zu blockieren
private let concealedPasteboardTypes: Set<NSPasteboard.PasteboardType> = [
    NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"),
    NSPasteboard.PasteboardType("de.petermaurer.transparency.pboard.type.suggesting.password"),
    NSPasteboard.PasteboardType("com.agilebits.onepassword"),
    NSPasteboard.PasteboardType("com.apple.is-password-autofill"),
    NSPasteboard.PasteboardType("com.dashlane.secureNote"),
]

class ClipboardManager: ObservableObject {
    @Published var history:   [ClipboardEntry] = []
    @Published var favorites: [ClipboardEntry] = []
    @Published var isPaused:  Bool = false

    private let maxHistory = 40
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var ticker: AnyCancellable?

    init() {
        loadAll()
        ticker = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.poll() }
    }

    // MARK: - Polling
    private func poll() {
        guard !isPaused else { return }

        let pb = NSPasteboard.general
        guard pb.changeCount != lastChangeCount else { return }
        lastChangeCount = pb.changeCount

        // Passwort-Schutz: Einträge mit ConcealedType-Flag überspringen
        let itemTypes = pb.pasteboardItems?.first?.types ?? []
        if itemTypes.contains(where: { concealedPasteboardTypes.contains($0) }) { return }

        guard let text = pb.string(forType: .string),
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }

        // Nicht duplizieren wenn gleicher Text wie letzter Eintrag
        if history.first?.text == text { return }
        // Auch nicht wenn bereits in Favoriten (identischer Text)
        // → trotzdem in History, damit Verlauf vollständig bleibt

        let entry = ClipboardEntry(text: text)
        history.insert(entry, at: 0)
        if history.count > maxHistory {
            history = Array(history.prefix(maxHistory))
        }
        saveHistory()
    }

    // MARK: - Aktionen
    func copyToClipboard(_ entry: ClipboardEntry) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(entry.text, forType: .string)
        lastChangeCount = pb.changeCount // verhindert dass eigene Kopie als neuer Eintrag gilt
    }

    func addManualEntry(label: String, text: String) {
        let entry = ClipboardEntry(text: text, label: label.isEmpty ? nil : label)
        favorites.insert(entry, at: 0)
        saveFavorites()
    }

    func updateFavorite(_ entry: ClipboardEntry) {
        if let i = favorites.firstIndex(where: { $0.id == entry.id }) {
            favorites[i] = entry
            saveFavorites()
        }
    }

    func addToFavorites(_ entry: ClipboardEntry) {
        guard !favorites.contains(where: { $0.text == entry.text }) else { return }
        favorites.append(entry)
        saveFavorites()
    }

    func removeFromFavorites(id: UUID) {
        favorites.removeAll { $0.id == id }
        saveFavorites()
    }

    func removeFromHistory(id: UUID) {
        history.removeAll { $0.id == id }
        saveHistory()
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func moveFavorite(from source: IndexSet, to destination: Int) {
        favorites.move(fromOffsets: source, toOffset: destination)
        saveFavorites()
    }

    // MARK: - Persistenz
    private func loadAll() {
        if let data = UserDefaults.standard.data(forKey: "clipHistory"),
           let list = try? JSONDecoder().decode([ClipboardEntry].self, from: data) {
            history = list
        }
        if let data = UserDefaults.standard.data(forKey: "clipFavorites"),
           let list = try? JSONDecoder().decode([ClipboardEntry].self, from: data) {
            favorites = list
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "clipHistory")
        }
    }

    private func saveFavorites() {
        if let data = try? JSONEncoder().encode(favorites) {
            UserDefaults.standard.set(data, forKey: "clipFavorites")
        }
    }
}
