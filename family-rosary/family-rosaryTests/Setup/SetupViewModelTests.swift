import XCTest
@testable import family_rosary

@MainActor
final class SetupViewModelTests: XCTestCase {
    func testInitLoadsSavedPartnerAndStyle() {
        let store = InMemoryRosaryPreferencesStore()
        store.lastPartnerID = "mom"
        store.lastPrayerStyle = .alwaysRespond

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
        viewModel.onTapPray()

        XCTAssertEqual(store.lastPartnerID, "mom")
        XCTAssertEqual(store.lastPrayerStyle, .alwaysLead)
        XCTAssertEqual(receivedRequest, StartRosaryRequest(partnerID: "mom", prayerStyle: .alwaysLead))
    }
}

private final class InMemoryRosaryPreferencesStore: RosaryPreferencesStore {
    var lastPartnerID: String?
    var lastPrayerStyle: PrayerStyle?

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
}
