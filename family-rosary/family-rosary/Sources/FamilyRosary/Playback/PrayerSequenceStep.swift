import Foundation

enum PrayerSequenceStep: Equatable {
    case play(url: URL, prompt: PrayerPrompt?)
    case pause(ms: Int, prompt: PrayerPrompt?)
    case waitForUtterance(UtteranceConfig, prompt: PrayerPrompt?)

    var prompt: PrayerPrompt? {
        switch self {
        case .play(_, let prompt):
            return prompt
        case .pause(_, let prompt):
            return prompt
        case .waitForUtterance(_, let prompt):
            return prompt
        }
    }
}
