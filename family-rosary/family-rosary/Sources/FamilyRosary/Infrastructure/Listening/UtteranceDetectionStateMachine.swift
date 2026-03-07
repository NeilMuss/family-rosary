import Foundation

enum UtteranceDetectionState: Equatable {
    case waitingForSpeechStart
    case speaking
    case waitingForSpeechEnd
    case completed
    case startTimedOut
    case maxDurationExceeded
}

struct UtteranceDetectionSnapshot: Equatable {
    let state: UtteranceDetectionState
    let didStartSpeaking: Bool
    let speechDuration: TimeInterval
    let silenceAccumulated: TimeInterval
    let elapsedBeforeSpeechStart: TimeInterval
    let elapsedSinceSpeechStart: TimeInterval
    let maxRMS: Float
}

struct UtteranceDetectionStateMachine {
    private let config: UtteranceConfig
    private let endThreshold: Float

    private(set) var state: UtteranceDetectionState = .waitingForSpeechStart
    private(set) var didStartSpeaking = false
    private(set) var speechDuration: TimeInterval = 0
    private(set) var silenceAccumulated: TimeInterval = 0
    private(set) var elapsedBeforeSpeechStart: TimeInterval = 0
    private(set) var elapsedSinceSpeechStart: TimeInterval = 0
    private(set) var maxRMS: Float = 0

    init(config: UtteranceConfig) {
        self.config = config
        self.endThreshold = config.endThreshold
    }

    mutating func consume(rms: Float, dt: TimeInterval) -> UtteranceDetectionSnapshot {
        guard state != .completed, state != .startTimedOut, state != .maxDurationExceeded else {
            return snapshot()
        }

        let clampedDt = max(0, dt)
        maxRMS = max(maxRMS, rms)

        if !didStartSpeaking {
            elapsedBeforeSpeechStart += clampedDt
            state = .waitingForSpeechStart

            if rms >= config.startThreshold {
                didStartSpeaking = true
                elapsedSinceSpeechStart = clampedDt
                speechDuration = clampedDt
                state = .speaking
                silenceAccumulated = 0
                return snapshot()
            }

            if elapsedBeforeSpeechStart >= config.startTimeoutSec {
                state = .startTimedOut
            }
            return snapshot()
        }

        elapsedSinceSpeechStart += clampedDt
        speechDuration += clampedDt

        if rms >= endThreshold {
            silenceAccumulated = 0
            state = .speaking
        } else {
            silenceAccumulated += clampedDt
            state = .waitingForSpeechEnd
        }

        if speechDuration >= config.minSpeechSec,
           silenceAccumulated >= config.completionSilenceSec {
            state = .completed
            return snapshot()
        }

        if elapsedSinceSpeechStart >= config.maxUtteranceSec {
            state = .maxDurationExceeded
        }

        return snapshot()
    }

    var hasNoInputSignal: Bool {
        !didStartSpeaking && maxRMS < 0.00001
    }

    private func snapshot() -> UtteranceDetectionSnapshot {
        UtteranceDetectionSnapshot(
            state: state,
            didStartSpeaking: didStartSpeaking,
            speechDuration: speechDuration,
            silenceAccumulated: silenceAccumulated,
            elapsedBeforeSpeechStart: elapsedBeforeSpeechStart,
            elapsedSinceSpeechStart: elapsedSinceSpeechStart,
            maxRMS: maxRMS
        )
    }
}
