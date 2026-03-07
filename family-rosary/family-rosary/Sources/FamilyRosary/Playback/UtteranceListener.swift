import Foundation

struct UtteranceConfig: Equatable {
    let speechStartThreshold: Float
    let speechContinueThreshold: Float
    let minSpeechSec: TimeInterval
    let completionSilenceSec: TimeInterval
    let startTimeoutSec: TimeInterval
    let maxUtteranceSec: TimeInterval

    var startThreshold: Float {
        speechStartThreshold
    }

    var continueThreshold: Float {
        speechContinueThreshold
    }

    static let `default` = UtteranceConfig(
        speechStartThreshold: 0.015,
        speechContinueThreshold: 0.00825,
        minSpeechSec: 0.5,
        completionSilenceSec: 1.1,
        startTimeoutSec: 4.0,
        maxUtteranceSec: 25.0
    )

    init(
        speechStartThreshold: Float,
        speechContinueThreshold: Float,
        minSpeechSec: TimeInterval,
        completionSilenceSec: TimeInterval,
        startTimeoutSec: TimeInterval,
        maxUtteranceSec: TimeInterval
    ) {
        self.speechStartThreshold = speechStartThreshold
        self.speechContinueThreshold = min(speechContinueThreshold, speechStartThreshold)
        self.minSpeechSec = minSpeechSec
        self.completionSilenceSec = completionSilenceSec
        self.startTimeoutSec = startTimeoutSec
        self.maxUtteranceSec = maxUtteranceSec
    }
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
