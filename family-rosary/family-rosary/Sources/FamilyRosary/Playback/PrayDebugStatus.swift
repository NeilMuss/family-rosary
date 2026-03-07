import Foundation

enum UtteranceDebugPhase: Equatable {
    case idle
    case userTurnWaitingForSpeechStart(
        rms: Float,
        startThreshold: Float,
        elapsed: TimeInterval,
        timeout: TimeInterval
    )
    case userTurnSpeechStarted
    case userTurnSpeaking(rms: Float)
    case userTurnWaitingForSpeechEnd(rms: Float, silenceElapsed: TimeInterval, required: TimeInterval)
    case userTurnCompleted
    case userTurnStartTimedOut
    case userTurnMaxDurationExceeded
    case waitingForSpeech(rms: Float, startThreshold: Float, endThreshold: Float)
    case speechDetected(rms: Float)
    case speaking(
        rms: Float,
        endThreshold: Float,
        speechDuration: TimeInterval,
        silenceAccumulated: TimeInterval,
        silenceRequired: TimeInterval,
        softSilenceRequired: TimeInterval,
        softMinSpeechSec: TimeInterval
    )
    case silenceCountdown(
        rms: Float,
        elapsed: TimeInterval,
        required: TimeInterval,
        speechDuration: TimeInterval,
        softSilenceRequired: TimeInterval,
        softMinSpeechSec: TimeInterval
    )
    case completed(reason: String)
    case timedOut
    case failed(String)
}

struct PrayDebugStatus: Equatable {
    let stepSummary: String
    let listenerPhase: UtteranceDebugPhase
}
