import Foundation

enum StorageError: Error {
    case encodeFailed
    case decodeFailed
}

final class Storage {
    static let shared = Storage()

    private let defaults = UserDefaults.standard
    private let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private enum Keys {
        static let scannedItems = "scantocart.scannedItems"
        static let settings = "scantocart.settings"
        static let onboardingComplete = "scantocart.onboardingComplete"
    }

    func loadScannedItems() -> [ScannedItem] {
        guard let data = defaults.data(forKey: Keys.scannedItems) else { return [] }
        return (try? decoder.decode([ScannedItem].self, from: data)) ?? []
    }

    func saveScannedItems(_ items: [ScannedItem]) {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: Keys.scannedItems)
    }

    func loadSettings() -> UserSettings {
        guard let data = defaults.data(forKey: Keys.settings),
              let settings = try? decoder.decode(UserSettings.self, from: data) else {
            return .default
        }
        return settings
    }

    func saveSettings(_ settings: UserSettings) {
        guard let data = try? encoder.encode(settings) else { return }
        defaults.set(data, forKey: Keys.settings)
    }

    var onboardingComplete: Bool {
        get { defaults.bool(forKey: Keys.onboardingComplete) }
        set { defaults.set(newValue, forKey: Keys.onboardingComplete) }
    }
}