/// Pure plan builder for one spoken rosary decade playback sequence.
import Foundation

enum RosaryPlanItem: Equatable {
    case play(token: String, pauseAfterMs: Int, prompt: PrayerPrompt)
    case waitForUtterance(UtteranceConfig, prompt: PrayerPrompt)
}

/// Builds an ordered list of token-based playback items for a full decade.
struct RosaryDecadePlanBuilder {
    static let hailMaryPairCount = 10

    func build(
        interactive: Bool = false,
        utteranceConfig: UtteranceConfig = .default
    ) -> [RosaryPlanItem] {
        if interactive {
            return buildInteractive(utteranceConfig: utteranceConfig)
        }

        var items = openingItems()
        items.append(contentsOf: hailMaryItems(repetitions: Self.hailMaryPairCount))
        return items
    }

    private func buildInteractive(utteranceConfig: UtteranceConfig) -> [RosaryPlanItem] {
        let pairs = openingPairs() + Array(repeating: hailMaryPair(), count: Self.hailMaryPairCount)
        var items: [RosaryPlanItem] = []
        items.reserveCapacity(pairs.count * 2)

        var userSpeaksLead = true
        for pair in pairs {
            if userSpeaksLead {
                items.append(
                    .waitForUtterance(
                        utteranceConfig,
                        prompt: PrayerPrompt(title: "Your turn", text: pair.prayer.firstLine)
                    )
                )
                items.append(
                    .play(
                        token: pair.responseToken,
                        pauseAfterMs: pair.responsePauseAfterMs,
                        prompt: PrayerPrompt(title: "Listen", text: pair.prayer.firstLine)
                    )
                )
            } else {
                items.append(
                    .play(
                        token: pair.leadToken,
                        pauseAfterMs: pair.leadPauseAfterMs,
                        prompt: PrayerPrompt(title: "Listen", text: pair.prayer.firstLine)
                    )
                )
                items.append(
                    .waitForUtterance(
                        utteranceConfig,
                        prompt: PrayerPrompt(title: "Your turn", text: pair.prayer.firstLine)
                    )
                )
            }
            userSpeaksLead.toggle()
        }

        return items
    }

    private func openingItems() -> [RosaryPlanItem] {
        [
            .play(
                token: "apostles_creed_lead",
                pauseAfterMs: 250,
                prompt: PrayerPrompt(title: "Listen", text: PrayerText.creedFirstLine)
            ),
            .play(
                token: "apostles_creed_response",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: PrayerText.creedFirstLine)
            ),
            .play(
                token: "our_father_lead",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: PrayerText.ourFatherFirstLine)
            ),
            .play(
                token: "our_father_response",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: PrayerText.ourFatherFirstLine)
            )
        ]
    }

    private func hailMaryItems(repetitions: Int) -> [RosaryPlanItem] {
        var items: [RosaryPlanItem] = []
        items.reserveCapacity(repetitions * 2)

        for _ in 0..<repetitions {
            items.append(
                .play(
                    token: "hail_lead",
                    pauseAfterMs: 400,
                    prompt: PrayerPrompt(title: "Listen", text: PrayerText.hailMaryFirstLine)
                )
            )
            items.append(
                .play(
                    token: "hail_response",
                    pauseAfterMs: 0,
                    prompt: PrayerPrompt(title: "Listen", text: PrayerText.hailMaryFirstLine)
                )
            )
        }

        return items
    }

    private func openingPairs() -> [PrayerPair] {
        [
            PrayerPair(
                prayer: .creed,
                leadToken: "apostles_creed_lead",
                responseToken: "apostles_creed_response",
                leadPauseAfterMs: 250,
                responsePauseAfterMs: 400
            ),
            PrayerPair(
                prayer: .ourFather,
                leadToken: "our_father_lead",
                responseToken: "our_father_response",
                leadPauseAfterMs: 400,
                responsePauseAfterMs: 400
            )
        ]
    }

    private func hailMaryPair() -> PrayerPair {
        PrayerPair(
            prayer: .hailMary,
            leadToken: "hail_lead",
            responseToken: "hail_response",
            leadPauseAfterMs: 400,
            responsePauseAfterMs: 0
        )
    }
}

private enum PrayerKind {
    case creed
    case ourFather
    case hailMary

    var firstLine: String {
        switch self {
        case .creed:
            return PrayerText.creedFirstLine
        case .ourFather:
            return PrayerText.ourFatherFirstLine
        case .hailMary:
            return PrayerText.hailMaryFirstLine
        }
    }
}

private struct PrayerPair {
    let prayer: PrayerKind
    let leadToken: String
    let responseToken: String
    let leadPauseAfterMs: Int
    let responsePauseAfterMs: Int
}

private enum PrayerText {
    static let creedFirstLine = "I believe in God, the Father almighty..."
    static let ourFatherFirstLine = "Our Father, who art in heaven..."
    static let hailMaryFirstLine = "Hail Mary, full of grace..."
}
