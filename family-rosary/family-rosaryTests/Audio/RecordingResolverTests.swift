import XCTest
@testable import family_rosary

final class RecordingResolverTests: XCTestCase {
    func testClosingHailHolyQueenFallsBackToExistingLeadFilenameToken() {
        let key = RecordingKey(prayer: .hailHolyQueen, part: .closingLead)

        XCTAssertEqual(
            key.candidateFilenameTokens,
            ["hail_holy_queen_closing", "hail_holy_queen_lead"]
        )
    }
}
