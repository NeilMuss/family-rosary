import Foundation

enum UtteranceDetectionState: Equatable {
    case waiting
    case speaking
    case completed
    case timedOut
}

enum UtteranceCompletionReason: Equatable {
    case hardSilence
    case softEnd
}

struct UtteranceDetectionSnapshot: Equatable {
    let state: UtteranceDetectionState
    let speechDetected: Bool
    let speechDuration: TimeInterval
    let silenceAccumulated: TimeInterval
    let elapsed: TimeInterval
    let maxRMS: Float
    let completionReason: UtteranceCompletionReason?
}

struct UtteranceDetectionStateMachine {
    static let softEndMinSpeechSec: TimeInterval = 2.0
    static let softEndSilenceSec: TimeInterval = 0.4

    private let config: UtteranceConfig
    private let endThreshold: Float

    private(set) var state: UtteranceDetectionState = .waiting
    private(set) var speechDetected = false
    private(set) var speechDuration: TimeInterval = 0
    private(set) var silenceAccumulated: TimeInterval = 0
    private(set) var elapsed: TimeInterval = 0
    private(set) var maxRMS: Float = 0
    private(set) var completionReason: UtteranceCompletionReason?

    init(config: UtteranceConfig) {
        self.config = config
        self.endThreshold = config.endThreshold
    }

    mutating func consume(rms: Float, dt: TimeInterval) -> UtteranceDetectionSnapshot {
        guard state != .completed, state != .timedOut else {
            return snapshot()
        }

        let clampedDt = max(0, dt)
        elapsed += clampedDt
        maxRMS = max(maxRMS, rms)

        if !speechDetected, rms >= config.startThreshold {
            speechDetected = true
            state = .speaking
        }

        if speechDetected {
            speechDuration += clampedDt
            if rms >= endThreshold {
                silenceAccumulated = 0
            } else {
                silenceAccumulated += clampedDt
            }

            if speechDuration >= config.minSpeechSec,
               silenceAccumulated >= config.silenceSecToEnd {
                state = .completed
                completionReason = .hardSilence
                return snapshot()
            }

            if speechDuration >= Self.softEndMinSpeechSec,
               silenceAccumulated >= Self.softEndSilenceSec {
                state = .completed
                completionReason = .softEnd
                return snapshot()
            }
        }

        if elapsed >= config.timeoutSec {
            state = .timedOut
        }

        return snapshot()
    }

    var hasNoInputSignal: Bool {
        !speechDetected && maxRMS < 0.00001
    }

    private func snapshot() -> UtteranceDetectionSnapshot {
        UtteranceDetectionSnapshot(
            state: state,
            speechDetected: speechDetected,
            speechDuration: speechDuration,
            silenceAccumulated: silenceAccumulated,
            elapsed: elapsed,
            maxRMS: maxRMS,
            completionReason: completionReason
        )
    }
}
