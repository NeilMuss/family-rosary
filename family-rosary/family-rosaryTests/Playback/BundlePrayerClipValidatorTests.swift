import XCTest
@testable import family_rosary

final class BundlePrayerClipValidatorTests: XCTestCase {
    func testValidatorRejectsMissingFile() {
        let clip = PrayerClip(
            id: "missing:clip",
            fileName: "this_file_does_not_exist.m4a",
            prayer: "hail_mary",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.0,
            endSec: 1.0
        )

        let validator = BundlePrayerClipValidator()
        let errors = validator.validate(clips: [clip], bundle: .main)

        XCTAssertEqual(errors.count, 1)
        XCTAssertTrue(errors[0].contains("missing bundle file"))
    }
}
