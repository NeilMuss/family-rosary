import Foundation
import XCTest
@testable import family_rosary

final class PrayerPartnerStoreTests: XCTestCase {
    func testFirstLoadSeedsDadAndMom() {
        let store = makeStore()

        XCTAssertEqual(store.all(), [
            PrayerPartner(id: "dad", displayName: "Dad"),
            PrayerPartner(id: "mom", displayName: "Mom")
        ])
    }

    func testRepeatedLoadsDoNotDuplicateSeeds() {
        let store = makeStore()

        _ = store.all()
        _ = store.all()

        XCTAssertEqual(store.all(), [
            PrayerPartner(id: "dad", displayName: "Dad"),
            PrayerPartner(id: "mom", displayName: "Mom")
        ])
    }

    func testAddPartnerPersists() {
        let userDefaults = makeUserDefaults()
        let store = UserDefaultsPrayerPartnerStore(userDefaults: userDefaults)

        store.add(PrayerPartner(id: "grandma", displayName: "Grandma"))

        let reloaded = UserDefaultsPrayerPartnerStore(userDefaults: userDefaults)
        XCTAssertTrue(reloaded.all().contains(PrayerPartner(id: "grandma", displayName: "Grandma")))
    }

    func testAddedPartnerIsReturnedByAll() {
        let store = makeStore()

        store.add(PrayerPartner(id: "grandpa", displayName: "Grandpa"))

        XCTAssertTrue(store.all().contains(PrayerPartner(id: "grandpa", displayName: "Grandpa")))
    }

    private func makeStore() -> UserDefaultsPrayerPartnerStore {
        UserDefaultsPrayerPartnerStore(userDefaults: makeUserDefaults())
    }

    private func makeUserDefaults() -> UserDefaults {
        let suiteName = "PrayerPartnerStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}
