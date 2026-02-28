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
    ) async throws {
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
            var emittedSpeechDetected = false
            let emitInterval: TimeInterval = 0.2

            emitDebug(
                .waitingForSpeech(
                    rms: 0,
                    startThreshold: config.startThreshold,
                    endThreshold: config.endThreshold
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

                if snapshot.speechDetected && !emittedSpeechDetected {
                    emitDebug(.speechDetected(rms: rms), to: onPhaseChanged)
                    emittedSpeechDetected = true
                }

                switch snapshot.state {
                case .waiting:
                    if shouldEmit(now: now, lastEmitAt: lastWaitingEmitAt, minInterval: emitInterval) {
                        emitDebug(
                            .waitingForSpeech(
                                rms: rms,
                                startThreshold: config.startThreshold,
                                endThreshold: config.endThreshold
                            ),
                            to: onPhaseChanged
                        )
                        lastWaitingEmitAt = now
                    }
                case .speaking:
                    if snapshot.silenceAccumulated > 0 {
                        if shouldEmit(now: now, lastEmitAt: lastSilenceEmitAt, minInterval: emitInterval) {
                            emitDebug(
                                .silenceCountdown(
                                    rms: rms,
                                    elapsed: snapshot.silenceAccumulated,
                                    required: config.silenceSecToEnd,
                                    speechDuration: snapshot.speechDuration,
                                    softSilenceRequired: UtteranceDetectionStateMachine.softEndSilenceSec,
                                    softMinSpeechSec: UtteranceDetectionStateMachine.softEndMinSpeechSec
                                ),
                                to: onPhaseChanged
                            )
                            lastSilenceEmitAt = now
                        }
                    } else {
                        if shouldEmit(now: now, lastEmitAt: lastSpeakingEmitAt, minInterval: emitInterval) {
                            emitDebug(
                                .speaking(
                                    rms: rms,
                                    endThreshold: config.endThreshold,
                                    speechDuration: snapshot.speechDuration,
                                    silenceAccumulated: snapshot.silenceAccumulated,
                                    silenceRequired: config.silenceSecToEnd,
                                    softSilenceRequired: UtteranceDetectionStateMachine.softEndSilenceSec,
                                    softMinSpeechSec: UtteranceDetectionStateMachine.softEndMinSpeechSec
                                ),
                                to: onPhaseChanged
                            )
                            lastSpeakingEmitAt = now
                        }
                    }
                case .completed:
                    let reason: String
                    switch snapshot.completionReason {
                    case .hardSilence:
                        reason = "hard-silence"
                    case .softEnd:
                        reason = "soft-end"
                    case nil:
                        reason = "unknown"
                    }
                    emitDebug(.completed(reason: reason), to: onPhaseChanged)
                    return
                case .timedOut:
                    if machine.hasNoInputSignal {
                        emitDebug(.failed("No input signal / rms~0"), to: onPhaseChanged)
                    }
                    emitDebug(.timedOut, to: onPhaseChanged)
                    throw UtteranceListenerError.timeout
                }

                try await Task.sleep(nanoseconds: 20_000_000)
            }
        } catch let error as UtteranceListenerError {
            if case .timeout = error {
                throw error
            }
            emitDebug(.failed(error.localizedDescription), to: onPhaseChanged)
            throw error
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
            options: [.defaultToSpeaker, .allowBluetooth]
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
