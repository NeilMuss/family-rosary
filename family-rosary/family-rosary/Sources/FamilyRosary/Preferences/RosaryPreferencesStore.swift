import Foundation

protocol RosaryPreferencesStore {
    func loadLastPartnerID() -> String?
    func saveLastPartnerID(_ id: String)
    func loadLastPrayerStyle() -> PrayerStyle?
    func saveLastPrayerStyle(_ style: PrayerStyle)
}

struct UserDefaultsRosaryPreferencesStore: RosaryPreferencesStore {
    private enum Keys {
        static let lastPartnerID = "rosary.lastPartnerID"
        static let lastPrayerStyle = "rosary.lastPrayerStyle"
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
}
