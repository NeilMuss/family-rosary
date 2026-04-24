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

    func test_decadeLabel_advances_across_decade_boundaries() {
        XCTAssertEqual(mapper.decadeLabel(for: 13), "1st Decade")
        XCTAssertEqual(mapper.decadeLabel(for: 37), "1st Decade")
        XCTAssertEqual(mapper.decadeLabel(for: 38), "2nd Decade")
        XCTAssertEqual(mapper.decadeLabel(for: 63), "3rd Decade")
        XCTAssertEqual(mapper.decadeLabel(for: 88), "4th Decade")
        XCTAssertEqual(mapper.decadeLabel(for: 113), "5th Decade")
    }

    func test_map_uses_active_step_index_for_decade_section_title() {
        let display = mapper.map(
            rosaryStepIndex: 38,
            prayerType: .ourFather,
            mode: .automatic,
            style: .alternateIStart,
            promptTitle: nil
        )

        XCTAssertEqual(display.sectionTitle, "2nd Decade")
    }
}
