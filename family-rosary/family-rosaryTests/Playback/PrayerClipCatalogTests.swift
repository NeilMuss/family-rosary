import XCTest
@testable import family_rosary

final class PrayerClipCatalogTests: XCTestCase {
    func testCatalogReturnsExpectedClips() {
        let catalog = StaticPrayerClipCatalog()
        let clips = catalog.allClips()

        XCTAssertFalse(clips.isEmpty)
        XCTAssertNotNil(catalog.clip(id: "dad:apostles_creed_lead"))
        XCTAssertNotNil(catalog.clip(id: "dad:hail_response"))
    }
}
