import Foundation

enum PrayerSegmentRole: Equatable {
    case lead
    case response
    case unison
}

enum PrayerSpeaker: Equatable {
    case user
    case partner
    case prayTogether
}

struct PrayerTurnPolicy {
    let style: PrayerStyle

    func speaker(for role: PrayerSegmentRole) -> PrayerSpeaker {
        switch role {
        case .unison:
            return .prayTogether
        case .lead:
            switch style {
            case .alternateIStart, .alwaysLead:
                return .user
            case .alternateIRespond, .alwaysRespond:
                return .partner
            }
        case .response:
            switch style {
            case .alternateIStart, .alwaysLead:
                return .partner
            case .alternateIRespond, .alwaysRespond:
                return .user
            }
        }
    }
}

struct InteractivePrayerPolicy {
    let userResponseTimeoutSec: TimeInterval
    let fallbackToSeedEnabled: Bool

    static let `default` = InteractivePrayerPolicy(
        userResponseTimeoutSec: 4.0,
        fallbackToSeedEnabled: true
    )
}
