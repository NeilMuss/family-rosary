import XCTest
@testable import family_rosary

final class RosaryPreferencesStoreTests: XCTestCase {
    func testCandleBackgroundDefaultsToDisabled() {
        let suiteName = "RosaryPreferencesStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = UserDefaultsRosaryPreferencesStore(userDefaults: userDefaults)

        XCTAssertFalse(store.loadCandleBackgroundEnabled())
    }

    func testCandleBackgroundPreferencePersists() {
        let suiteName = "RosaryPreferencesStoreTests.\(UUID().uuidString)"
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        let store = UserDefaultsRosaryPreferencesStore(userDefaults: userDefaults)

        store.saveCandleBackgroundEnabled(true)

        XCTAssertTrue(store.loadCandleBackgroundEnabled())
    }
}
