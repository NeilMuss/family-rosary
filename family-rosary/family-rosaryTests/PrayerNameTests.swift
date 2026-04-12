import XCTest
@testable import family_rosary

final class PrayerNameTests: XCTestCase {
    func testDisplayNameValuesAreCorrect() {
        XCTAssertEqual(PrayerName.apostlesCreed.displayName, "Apostles' Creed")
        XCTAssertEqual(PrayerName.ourFather.displayName, "Our Father")
        XCTAssertEqual(PrayerName.hailMary.displayName, "Hail Mary")
    }

    func testAvailablePartsMappingIsCorrect() {
        XCTAssertEqual(PrayerName.apostlesCreed.availableParts, [.apostlesCreed])
        XCTAssertEqual(PrayerName.ourFather.availableParts, [.ourFatherLead, .ourFatherResponse])
        XCTAssertEqual(PrayerName.hailMary.availableParts, [.hailMaryLead, .hailMaryResponse])
    }
}
