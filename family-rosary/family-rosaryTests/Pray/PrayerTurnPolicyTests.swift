import XCTest
@testable import family_rosary

final class PrayerTurnPolicyTests: XCTestCase {
    func test_alternate_i_start_user_leads_apostles_creed_and_first_our_father() {
        let policy = PrayerTurnPolicy(style: .alternateIStart)

        XCTAssertEqual(policy.speaker(for: .lead), .user)
        XCTAssertEqual(policy.speaker(for: .lead), .user)
        XCTAssertEqual(policy.speaker(for: .response), .partner)
    }

    func test_unison_prayer_behavior_is_explicit_and_deterministic() {
        let allStyles: [PrayerStyle] = [.alternateIStart, .alternateIRespond, .alwaysLead, .alwaysRespond]

        for style in allStyles {
            let policy = PrayerTurnPolicy(style: style)
            XCTAssertEqual(policy.speaker(for: .unison), .prayTogether)
        }
    }
}
