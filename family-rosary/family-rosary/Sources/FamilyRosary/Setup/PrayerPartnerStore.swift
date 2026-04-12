import Foundation

protocol PrayerPartnerStoring {
    func all() -> [PrayerPartner]
    func add(_ partner: PrayerPartner)
}

struct UserDefaultsPrayerPartnerStore: PrayerPartnerStoring {
    private enum Keys {
        static let partners = "setup.prayerPartners"
    }

    private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
    }

    func all() -> [PrayerPartner] {
        let decoded = loadStoredPartners()
        if decoded.isEmpty {
            let seeded = Self.seedPartners
            persist(seeded)
            return seeded
        }
        return decoded
    }

    func add(_ partner: PrayerPartner) {
        var partners = all()
        partners.removeAll { $0.id == partner.id }
        partners.append(partner)
        persist(partners.sorted { $0.id < $1.id })
    }

    private func loadStoredPartners() -> [PrayerPartner] {
        guard let data = userDefaults.data(forKey: Keys.partners) else {
            return []
        }
        return (try? JSONDecoder().decode([PrayerPartner].self, from: data)) ?? []
    }

    private func persist(_ partners: [PrayerPartner]) {
        guard let data = try? JSONEncoder().encode(partners) else {
            return
        }
        userDefaults.set(data, forKey: Keys.partners)
    }

    private static let seedPartners = [
        PrayerPartner(id: "dad", displayName: "Dad"),
        PrayerPartner(id: "mom", displayName: "Mom")
    ]
}
