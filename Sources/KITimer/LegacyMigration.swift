import Foundation

/// Übernimmt einmalig die Einstellungen aus der früheren Bundle-ID `de.fehu.central`.
enum LegacyMigration {
    private static let legacyDomain = "de.fehu.central"
    private static let doneKey = "migratedFromLegacyBundle"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: doneKey) else { return }
        if let old = defaults.persistentDomain(forName: legacyDomain) {
            for (key, value) in old
            where !key.hasPrefix("NSStatusItem") && !key.hasPrefix("NS") && !key.hasPrefix("Apple")
                && defaults.object(forKey: key) == nil {
                defaults.set(value, forKey: key)
            }
        }
        defaults.set(true, forKey: doneKey)
    }
}
