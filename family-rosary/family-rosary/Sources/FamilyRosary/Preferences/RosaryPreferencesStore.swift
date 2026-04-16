import Foundation

protocol RosaryPreferencesStore {
    func loadLastPartnerID() -> String?
    func saveLastPartnerID(_ id: String)
    func loadLastPrayerStyle() -> PrayerStyle?
    func saveLastPrayerStyle(_ style: PrayerStyle)
    func loadLastPrayerMode() -> PrayerMode?
    func saveLastPrayerMode(_ mode: PrayerMode)
    func loadCandleBackgroundEnabled() -> Bool
    func saveCandleBackgroundEnabled(_ enabled: Bool)
}

struct UserDefaultsRosaryPreferencesStore: RosaryPreferencesStore {
    private enum Keys {
        static let lastPartnerID = "rosary.lastPartnerID"
        static let lastPrayerStyle = "rosary.lastPrayerStyle"
        static let lastPrayerMode = "rosary.lastPrayerMode"
        static let candleBackgroundEnabled = "rosary.candleBackgroundEnabled"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func loadLastPartnerID() -> String? {
        userDefaults.string(forKey: Keys.lastPartnerID)
    }

    func saveLastPartnerID(_ id: String) {
        userDefaults.set(id, forKey: Keys.lastPartnerID)
    }

    func loadLastPrayerStyle() -> PrayerStyle? {
        guard let rawValue = userDefaults.string(forKey: Keys.lastPrayerStyle) else {
            return nil
        }
        return PrayerStyle(rawValue: rawValue)
    }

    func saveLastPrayerStyle(_ style: PrayerStyle) {
        userDefaults.set(style.rawValue, forKey: Keys.lastPrayerStyle)
    }

    func loadLastPrayerMode() -> PrayerMode? {
        guard let rawValue = userDefaults.string(forKey: Keys.lastPrayerMode) else {
            return nil
        }
        return PrayerMode(rawValue: rawValue)
    }

    func saveLastPrayerMode(_ mode: PrayerMode) {
        userDefaults.set(mode.rawValue, forKey: Keys.lastPrayerMode)
    }

    func loadCandleBackgroundEnabled() -> Bool {
        userDefaults.bool(forKey: Keys.candleBackgroundEnabled)
    }

    func saveCandleBackgroundEnabled(_ enabled: Bool) {
        userDefaults.set(enabled, forKey: Keys.candleBackgroundEnabled)
    }
}
