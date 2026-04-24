import XCTest
@testable import family_rosary

@MainActor
final class SetupViewModelTests: XCTestCase {
    func testInitLoadsSavedPartnerAndStyle() {
        let store = InMemoryRosaryPreferencesStore()
        store.lastPartnerID = "mom"
        store.lastPrayerStyle = .alwaysRespond
        store.lastPrayerMode = .automatic
        store.candleBackgroundEnabled = true

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
        XCTAssertTrue(viewModel.isCandleBackgroundEnabled)
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

    func test_default_style_is_always_respond_when_no_saved_value() {
        let store = InMemoryRosaryPreferencesStore()

        let viewModel = SetupViewModel(
            availablePartners: [
                PrayerPartner(id: "dad", displayName: "Dad"),
                PrayerPartner(id: "mom", displayName: "Mom")
            ],
            preferencesStore: store,
            onStartPraying: { _ in }
        )

        XCTAssertEqual(viewModel.selectedStyle, .alwaysRespond)
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
        viewModel.setCandleBackgroundEnabled(true)
        viewModel.onTapPray()

        XCTAssertEqual(store.lastPartnerID, "mom")
        XCTAssertEqual(store.lastPrayerStyle, .alwaysLead)
        XCTAssertEqual(store.lastPrayerMode, .automatic)
        XCTAssertTrue(store.candleBackgroundEnabled)
        XCTAssertEqual(
            receivedRequest,
            StartRosaryRequest(partnerID: "mom", prayerStyle: .alwaysLead, prayerMode: .automatic)
        )
    }

    func testShowOnboardingUsesConfiguredCallback() {
        let store = InMemoryRosaryPreferencesStore()
        var didShow = false

        let viewModel = SetupViewModel(
            availablePartners: [
                PrayerPartner(id: "dad", displayName: "Dad")
            ],
            preferencesStore: store,
            onStartPraying: { _ in },
            onShowOnboarding: {
                didShow = true
            }
        )

        viewModel.showOnboarding()

        XCTAssertTrue(didShow)
    }
}

private final class InMemoryRosaryPreferencesStore: RosaryPreferencesStore {
    var lastPartnerID: String?
    var lastPrayerStyle: PrayerStyle?
    var lastPrayerMode: PrayerMode?
    var candleBackgroundEnabled = false
    var hasSeenOnboarding = false

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

    func loadHasSeenOnboarding() -> Bool {
        hasSeenOnboarding
    }

    func saveHasSeenOnboarding(_ hasSeen: Bool) {
        hasSeenOnboarding = hasSeen
    }
}
