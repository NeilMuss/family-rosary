import Foundation

// Kept outside `PrayViewModel.swift` so prayer-type mapping stays out of the
// `@MainActor` view-model context. This keeps the domain/application path that
// eventually produces `PrayerLineKey` free of accidental actor isolation.
extension PrayerType {
    var segmentDefinition: PrayerSegmentDefinition {
        switch self {
        case .apostlesCreedLead:
            return PrayerSegmentDefinition(
                token: "apostles_creed_lead",
                pauseAfterMs: 250,
                promptText: "I believe in God, the Father almighty...",
                role: .lead
            )
        case .apostlesCreedResponse:
            return PrayerSegmentDefinition(
                token: "apostles_creed_response",
                pauseAfterMs: 400,
                promptText: "I believe in God, the Father almighty...",
                role: .response
            )
        case .ourFatherLead:
            return PrayerSegmentDefinition(
                token: "our_father_lead",
                pauseAfterMs: 400,
                promptText: "Our Father, who art in heaven...",
                role: .lead
            )
        case .ourFatherResponse:
            return PrayerSegmentDefinition(
                token: "our_father_response",
                pauseAfterMs: 400,
                promptText: "Our Father, who art in heaven...",
                role: .response
            )
        case .hailMaryLead:
            return PrayerSegmentDefinition(
                token: "hail_lead",
                pauseAfterMs: 400,
                promptText: "Hail Mary, full of grace...",
                role: .lead
            )
        case .hailMaryResponse:
            return PrayerSegmentDefinition(
                token: "hail_response",
                pauseAfterMs: 0,
                promptText: "Hail Mary, full of grace...",
                role: .response
            )
        case .gloryBeLead:
            return PrayerSegmentDefinition(
                token: "glory_be_lead",
                pauseAfterMs: 300,
                promptText: "Glory be to the Father...",
                role: .lead
            )
        case .gloryBeResponse:
            return PrayerSegmentDefinition(
                token: "glory_be_response",
                pauseAfterMs: 300,
                promptText: "Glory be to the Father...",
                role: .response
            )
        case .fatima:
            return PrayerSegmentDefinition(
                token: "fatima",
                pauseAfterMs: 300,
                promptText: "O my Jesus, forgive us our sins...",
                role: .unison
            )
        // Hail Holy Queen is modeled as multiple segments to support proper call/response structure.
        case .hailHolyQueenOpeningLead:
            return PrayerSegmentDefinition(
                token: "hail_holy_queen_lead",
                pauseAfterMs: 400,
                promptText: "Hail, holy Queen, Mother of mercy...",
                role: .lead
            )
        case .hailHolyQueenResponse:
            return PrayerSegmentDefinition(
                token: "hail_holy_queen_response",
                pauseAfterMs: 250,
                promptText: "Pray for us, most holy Mother of God.",
                role: .response
            )
        case .hailHolyQueenClosingLead:
            return PrayerSegmentDefinition(
                token: "hail_holy_queen_closing",
                pauseAfterMs: 0,
                promptText: "That we may be made worthy of the promises of Christ.",
                role: .lead
            )
        }
    }
}

struct PrayerSegmentDefinition {
    let token: String
    let pauseAfterMs: Int
    let promptText: String
    let role: PrayerSegmentRole

    var listenPrompt: PrayerPrompt {
        PrayerPrompt(title: "Listen", text: promptText)
    }

    var yourTurnPrompt: PrayerPrompt {
        PrayerPrompt(title: "Your turn", text: promptText)
    }

    var togetherPrompt: PrayerPrompt {
        PrayerPrompt(title: "Pray together", text: promptText)
    }
}
