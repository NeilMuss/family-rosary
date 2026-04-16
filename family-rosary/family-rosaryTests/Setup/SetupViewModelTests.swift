import XCTest
@testable import family_rosary

@MainActor
final class SetupViewModelTests: XCTestCase {
    func testInitLoadsSavedPartnerAndStyle() {
        let store = InMemoryRosaryPreferencesStore()
        store.lastPartnerID = "mom"
        store.lastPrayerStyle = .alwaysRespond
        store.lastPrayerMode = .automatic

        let viewModel = SetupViewModel(
            availablePartners: [
                PrayerPartner(id: "dad", displayName: "Dad"),
                PrayerPartner(id: "mom", displayName: "Mom")
            ],
            preferencesStore: store,
            onStartPraying: { _ in }
        )

        XCTAssertEqual(viewModel.selectedPartnerID, "mom")
        XCTAssertEqual(viewModel.selectedStyle, .alwaysRespond)
        XCTAssertEqual(viewModel.selectedMode, .automatic)
    }

    func test_default_mode_is_interactive_when_no_saved_value() {
        let store = InMemoryRosaryPreferencesStore()

        let viewModel = SetupViewModel(
            availablePartners: [
                PrayerPartner(id: "dad", displayName: "Dad"),
                PrayerPartner(id: "mom", displayName: "Mom")
            ],
            preferencesStore: store,
            onStartPraying: { _ in }
        )

        XCTAssertEqual(viewModel.selectedMode, .interactive)
    }

    func testOnTapPraySavesPreferencesAndEmitsRequest() {
        let store = InMemoryRosaryPreferencesStore()
        var receivedRequest: StartRosaryRequest?

        let viewModel = SetupViewModel(
            availablePartners: [
                PrayerPartner(id: "dad", displayName: "Dad"),
                PrayerPartner(id: "mom", displayName: "Mom")
            ],
            preferencesStore: store,
            onStartPraying: { request in
                receivedRequest = request
            }
        )

        viewModel.selectedPartnerID = "mom"
        viewModel.selectedStyle = .alwaysLead
        viewModel.selectedMode = .automatic
        viewModel.onTapPray()

        XCTAssertEqual(store.lastPartnerID, "mom")
        XCTAssertEqual(store.lastPrayerStyle, .alwaysLead)
        XCTAssertEqual(store.lastPrayerMode, .automatic)
        XCTAssertEqual(
            receivedRequest,
            StartRosaryRequest(partnerID: "mom", prayerStyle: .alwaysLead, prayerMode: .automatic)
        )
    }
}

private final class InMemoryRosaryPreferencesStore: RosaryPreferencesStore {
    var lastPartnerID: String?
    var lastPrayerStyle: PrayerStyle?
    var lastPrayerMode: PrayerMode?
    var candleBackgroundEnabled = false

    func loadLastPartnerID() -> String? {
        lastPartnerID
    }

    func saveLastPartnerID(_ id: String) {
        lastPartnerID = id
    }

    func loadLastPrayerStyle() -> PrayerStyle? {
        lastPrayerStyle
    }

    func saveLastPrayerStyle(_ style: PrayerStyle) {
        lastPrayerStyle = style
    }

    func loadLastPrayerMode() -> PrayerMode? {
        lastPrayerMode
    }

    func saveLastPrayerMode(_ mode: PrayerMode) {
        lastPrayerMode = mode
    }

    func loadCandleBackgroundEnabled() -> Bool {
        candleBackgroundEnabled
    }

    func saveCandleBackgroundEnabled(_ enabled: Bool) {
        candleBackgroundEnabled = enabled
    }
}
