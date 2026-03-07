import AVFoundation
import Foundation

final class EnergyUtteranceListener: UtteranceListener {
    private let engine: AVAudioEngine
    private let energyStore = EnergyStore()

    init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
    }

    func waitForUtterance(
        config: UtteranceConfig,
        onPhaseChanged: ((UtteranceDebugPhase) -> Void)?
    ) async throws -> UtteranceWaitResult {
        do {
            try prepareSession()
            try installTap()
            try engine.start()

            defer {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
            }

            var machine = UtteranceDetectionStateMachine(config: config)
            var lastLoopAt = Date()
            var lastSpeakingEmitAt: Date?
            var lastWaitingEmitAt: Date?
            var lastSilenceEmitAt: Date?
            var emittedSpeechStarted = false
            let emitInterval: TimeInterval = 0.2

            emitDebug(
                .userTurnWaitingForSpeechStart(
                    rms: 0,
                    startThreshold: config.startThreshold,
                    elapsed: 0,
                    timeout: config.startTimeoutSec
                ),
                to: onPhaseChanged
            )

            while true {
                try Task.checkCancellation()

                let now = Date()
                let dt = now.timeIntervalSince(lastLoopAt)
                lastLoopAt = now
                let rms = energyStore.current

                let snapshot = machine.consume(rms: rms, dt: dt)

                if snapshot.didStartSpeaking && !emittedSpeechStarted {
                    emitDebug(.userTurnSpeechStarted, to: onPhaseChanged)
                    emittedSpeechStarted = true
                }

                switch snapshot.state {
                case .waitingForSpeechStart:
                    if shouldEmit(now: now, lastEmitAt: lastWaitingEmitAt, minInterval: emitInterval) {
                        emitDebug(
                            .userTurnWaitingForSpeechStart(
                                rms: rms,
                                startThreshold: config.startThreshold,
                                elapsed: snapshot.elapsedBeforeSpeechStart,
                                timeout: config.startTimeoutSec
                            ),
                            to: onPhaseChanged
                        )
                        lastWaitingEmitAt = now
                    }
                case .speaking:
                    if shouldEmit(now: now, lastEmitAt: lastSpeakingEmitAt, minInterval: emitInterval) {
                        emitDebug(
                            .userTurnSpeaking(
                                rms: rms,
                                continueThreshold: config.speechContinueThreshold
                            ),
                            to: onPhaseChanged
                        )
                        lastSpeakingEmitAt = now
                    }
                case .waitingForSpeechEnd:
                    if shouldEmit(now: now, lastEmitAt: lastSilenceEmitAt, minInterval: emitInterval) {
                        emitDebug(
                            .userTurnWaitingForSpeechEnd(
                                rms: rms,
                                silenceElapsed: snapshot.silenceAccumulated,
                                required: config.completionSilenceSec,
                                continueThreshold: config.speechContinueThreshold
                            ),
                            to: onPhaseChanged
                        )
                        lastSilenceEmitAt = now
                    }
                case .completed:
                    emitDebug(.userTurnCompleted, to: onPhaseChanged)
                    return .completedByUser
                case .startTimedOut:
                    if machine.hasNoInputSignal {
                        emitDebug(.failed("No input signal / rms~0"), to: onPhaseChanged)
                    }
                    emitDebug(.userTurnStartTimedOut, to: onPhaseChanged)
                    return .startTimedOut
                case .maxDurationExceeded:
                    emitDebug(.userTurnMaxDurationExceeded, to: onPhaseChanged)
                    return .maxDurationExceeded
                }

                try await Task.sleep(nanoseconds: 20_000_000)
            }
        } catch {
            emitDebug(.failed(error.localizedDescription), to: onPhaseChanged)
            throw error
        }
    }

    private func prepareSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        try session.setActive(true)
    }

    private func installTap() throws {
        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        if format.channelCount == 0 {
            throw NSError(
                domain: "EnergyUtteranceListener",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No microphone input channel available."]
            )
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [energyStore] buffer, _ in
            energyStore.current = Self.rms(of: buffer)
        }
    }

    private func shouldEmit(
        now: Date,
        lastEmitAt: Date?,
        minInterval: TimeInterval
    ) -> Bool {
        guard let lastEmitAt else { return true }
        return now.timeIntervalSince(lastEmitAt) >= minInterval
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channel = channelData[0]
        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return 0 }

        var sum: Float = 0
        for idx in 0..<frameCount {
            let sample = channel[idx]
            sum += sample * sample
        }

        return sqrt(sum / Float(frameCount))
    }

    private func emitDebug(
        _ phase: UtteranceDebugPhase,
        to sink: ((UtteranceDebugPhase) -> Void)?
    ) {
        #if DEBUG
        sink?(phase)
        #else
        _ = phase
        _ = sink
        #endif
    }
}

private final class EnergyStore {
    private let lock = NSLock()
    private var value: Float = 0

    var current: Float {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            value = newValue
            lock.unlock()
        }
    }
}
