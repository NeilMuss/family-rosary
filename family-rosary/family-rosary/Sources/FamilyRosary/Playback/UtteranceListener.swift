import Foundation

struct UtteranceConfig: Equatable {
    let startThreshold: Float
    let endThresholdMultiplier: Float
    let minSpeechSec: TimeInterval
    let silenceSecToEnd: TimeInterval
    let timeoutSec: TimeInterval

    var endThreshold: Float {
        startThreshold * endThresholdMultiplier
    }

    static let `default` = UtteranceConfig(
        startThreshold: 0.015,
        endThresholdMultiplier: 0.55,
        minSpeechSec: 0.5,
        silenceSecToEnd: 0.7,
        timeoutSec: 25.0
    )
}

enum UtteranceListenerError: Error, LocalizedError {
    case timeout

    var errorDescription: String? {
        switch self {
        case .timeout:
            return "Timed out waiting for spoken response."
        }
    }
}

protocol UtteranceListener {
    func waitForUtterance(
        config: UtteranceConfig,
        onPhaseChanged: ((UtteranceDebugPhase) -> Void)?
    ) async throws
}
