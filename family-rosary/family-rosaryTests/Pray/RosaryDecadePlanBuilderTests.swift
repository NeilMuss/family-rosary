import XCTest
@testable import family_rosary

final class RosaryDecadePlanBuilderTests: XCTestCase {
    func testBuildReturnsOpeningPrayersThenTenHailMaryPairsWithListenPrompts() {
        let items = RosaryDecadePlanBuilder().build()

        XCTAssertEqual(items.count, 24)

        XCTAssertEqual(
            items[0],
            .play(
                token: "apostles_creed_lead",
                pauseAfterMs: 250,
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        )
        XCTAssertEqual(
            items[2],
            .play(
                token: "our_father_lead",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "Our Father, who art in heaven...")
            )
        )
        XCTAssertEqual(
            items[4],
            .play(
                token: "hail_lead",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "Hail Mary, full of grace...")
            )
        )
    }

    func testInteractiveBuildUsesYourTurnForWaitAndListenForPlay() {
        let utteranceConfig = UtteranceConfig.default
        let items = RosaryDecadePlanBuilder().build(interactive: true, utteranceConfig: utteranceConfig)

        XCTAssertEqual(items.count, 24)

        XCTAssertEqual(
            items[0],
            .waitForUtterance(
                utteranceConfig,
                prompt: PrayerPrompt(title: "Your turn", text: "I believe in God, the Father almighty...")
            )
        )
        XCTAssertEqual(
            items[1],
            .play(
                token: "apostles_creed_response",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        )
    }
}
