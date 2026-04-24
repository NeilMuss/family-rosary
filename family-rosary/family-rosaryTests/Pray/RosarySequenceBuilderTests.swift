import XCTest
@testable import family_rosary

final class RosarySequenceBuilderTests: XCTestCase {
    func test_standard_rosary_sequence_count() {
        let sequence = RosarySequenceBuilder.makeStandardRosary()

        XCTAssertEqual(sequence.count, 140)
    }

    func test_standard_rosary_sequence_fatima_appears_five_times() {
        let sequence = RosarySequenceBuilder.makeStandardRosary()

        XCTAssertEqual(sequence.filter { $0 == .fatima }.count, 5)
    }

    func test_standard_rosary_sequence_closes_with_three_hail_holy_queen_segments() {
        let sequence = RosarySequenceBuilder.makeStandardRosary()

        XCTAssertEqual(
            Array(sequence.suffix(3)),
            [.hailHolyQueenOpeningLead, .hailHolyQueenResponse, .hailHolyQueenClosingLead]
        )
    }
}
