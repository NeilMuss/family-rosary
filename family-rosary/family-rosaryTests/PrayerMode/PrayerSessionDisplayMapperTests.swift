import XCTest
@testable import family_rosary

final class PrayerSessionDisplayMapperTests: XCTestCase {
    private let mapper = PrayerSessionDisplayMapper()

    func test_automatic_mode_never_shows_now_your_turn() {
        let display = mapper.map(
            rosaryStepIndex: 1,
            prayerType: .apostlesCreed,
            mode: .automatic,
            style: .alwaysLead,
            promptTitle: nil
        )

        XCTAssertNotEqual(display.rolePrompt, "Now your turn")
        XCTAssertNil(display.rolePrompt)
    }

    func test_intro_hail_mary_count_formats_as_1_of_3() {
        let display = mapper.map(
            rosaryStepIndex: 5,
            prayerType: .hailMary,
            mode: .automatic,
            style: .alternateIStart,
            promptTitle: nil
        )

        XCTAssertEqual(display.countText, "1 of 3")
    }

    func test_decade_hail_mary_count_formats_as_1_of_10() {
        let display = mapper.map(
            rosaryStepIndex: 15,
            prayerType: .hailMary,
            mode: .automatic,
            style: .alternateIStart,
            promptTitle: nil
        )

        XCTAssertEqual(display.countText, "1 of 10")
    }

    func test_non_hail_mary_has_no_count_text() {
        let display = mapper.map(
            rosaryStepIndex: 1,
            prayerType: .apostlesCreed,
            mode: .automatic,
            style: .alternateIStart,
            promptTitle: nil
        )

        XCTAssertNil(display.countText)
    }
}
