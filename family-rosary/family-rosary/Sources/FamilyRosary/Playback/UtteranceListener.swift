import Foundation

struct UtteranceConfig: Equatable {
    let startThreshold: Float
    let endThresholdMultiplier: Float
    let minSpeechSec: TimeInterval
    let completionSilenceSec: TimeInterval
    let startTimeoutSec: TimeInterval
    let maxUtteranceSec: TimeInterval

    var endThreshold: Float {
        startThreshold * endThresholdMultiplier
    }

    static let `default` = UtteranceConfig(
        startThreshold: 0.015,
        endThresholdMultiplier: 0.55,
        minSpeechSec: 0.5,
        completionSilenceSec: 0.7,
        startTimeoutSec: 4.0,
        maxUtteranceSec: 25.0
    )
}

enum UtteranceWaitResult: Equatable {
    case completedByUser
    case startTimedOut
    case maxDurationExceeded
}

enum InteractiveTurnResult: Equatable {
    case completedByUser
    case fellBackToSeed
    case timedOutAfterSpeechStarted
}

enum UtteranceListenerError: Error, LocalizedError {
    case configuration(String)

    var errorDescription: String? {
        switch self {
        case .configuration(let message):
            return message
        }
    }
}

protocol UtteranceListener {
    func waitForUtterance(
        config: UtteranceConfig,
        onPhaseChanged: ((UtteranceDebugPhase) -> Void)?
    ) async throws -> UtteranceWaitResult
}
