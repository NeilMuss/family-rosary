import XCTest
@testable import family_rosary

final class PrayerNameTests: XCTestCase {
    func testDisplayNameValuesAreCorrect() {
        XCTAssertEqual(PrayerName.apostlesCreed.displayName, "Apostles' Creed")
        XCTAssertEqual(PrayerName.ourFather.displayName, "Our Father")
        XCTAssertEqual(PrayerName.hailMary.displayName, "Hail Mary")
        XCTAssertEqual(PrayerName.gloryBe.displayName, "Glory Be")
        XCTAssertEqual(PrayerName.fatima.displayName, "Fatima Prayer")
        XCTAssertEqual(PrayerName.hailHolyQueen.displayName, "Hail Holy Queen")
    }

    func testAvailablePartsMappingIsCorrect() {
        XCTAssertEqual(PrayerName.apostlesCreed.availableParts, [.apostlesCreed])
        XCTAssertEqual(PrayerName.ourFather.availableParts, [.ourFatherLead, .ourFatherResponse])
        XCTAssertEqual(PrayerName.hailMary.availableParts, [.hailMaryLead, .hailMaryResponse])
        XCTAssertEqual(PrayerName.gloryBe.availableParts, [.gloryBeLead, .gloryBeResponse])
        XCTAssertEqual(PrayerName.fatima.availableParts, [.fatima])
        XCTAssertEqual(
            PrayerName.hailHolyQueen.availableParts,
            [.hailHolyQueenLead, .hailHolyQueenResponse, .hailHolyQueenClosing]
        )
    }

    func testSupportedImportPrayersIncludeCoreSupportedPrayers() {
        XCTAssertTrue(PrayerName.supportedImportPrayers.contains(.hailMary))
        XCTAssertTrue(PrayerName.supportedImportPrayers.contains(.ourFather))
        XCTAssertTrue(PrayerName.supportedImportPrayers.contains(.gloryBe))
    }
}
