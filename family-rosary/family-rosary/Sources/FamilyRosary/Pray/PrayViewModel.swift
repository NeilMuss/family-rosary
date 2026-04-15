import Foundation
import Combine

@MainActor
final class PrayViewModel: ObservableObject {
    @Published var isPraying = false
    @Published var isPreparingAudio = false
    @Published var isInteractive = false
    @Published var currentPrompt: PrayerPrompt?
    #if DEBUG
    @Published var debugText: String = ""
    @Published var debugLog: [String] = []
    @Published var latestDebugStatus: PrayDebugStatus?
    #endif
    @Published var errorMessage: String?
    @Published var showMicrophoneDeniedAlert = false
    var interactiveStyle: PrayerStyle = .alternateIStart
    var interactivePolicy: InteractivePrayerPolicy = .default
    var interactiveCalibration: InteractiveCalibration?

    private let personID: String
    private let sequencePlayer: PrayerSequencePlaying
    private let resolver: AudioFileResolving
    private let microphonePermissionClient: MicrophonePermissionClient
    private let idleTimerController: IdleTimerControlling
    private var playTask: Task<Void, Never>?
    private var isStartingPrayer = false
    private var isHoldingIdleTimer = false

    init(
        personID: String = "dad",
        sequencePlayer: PrayerSequencePlaying,
        resolver: AudioFileResolving,
        microphonePermissionClient: MicrophonePermissionClient,
        idleTimerController: IdleTimerControlling? = nil
    ) {
        self.personID = personID
        self.sequencePlayer = sequencePlayer
        self.resolver = resolver
        self.microphonePermissionClient = microphonePermissionClient
        self.idleTimerController = idleTimerController ?? ApplicationIdleTimerController()
    }

    func onTapPray() {
        guard !isPraying, !isStartingPrayer else { return }
        errorMessage = nil
        currentPrompt = nil
        #if DEBUG
        debugText = ""
        latestDebugStatus = nil
        DebugLog.shared.log("MODE \(isInteractive ? "interactive" : "automatic")")
        #endif
        showMicrophoneDeniedAlert = false

        if !isInteractive {
            startPrayerPlayback()
            return
        }

        isStartingPrayer = true
        Task { [weak self] in
            guard let self else { return }
            let granted = await self.microphonePermissionClient.requestAccess()
            self.isStartingPrayer = false

            guard granted else {
                self.errorMessage = "Microphone access is required for Interactive mode."
                self.currentPrompt = nil
                #if DEBUG
                self.debugText = ""
                #endif
                self.showMicrophoneDeniedAlert = true
                #if DEBUG
                DebugLog.shared.log("MIC permissionDenied")
                #endif
                return
            }

            self.startPrayerPlayback()
        }
    }

    func onTapStop() {
        playTask?.cancel()
        sequencePlayer.stop()
        restoreIdleTimerIfNeeded()
        isPraying = false
        isPreparingAudio = false
        currentPrompt = nil
        #if DEBUG
        debugText = ""
        latestDebugStatus = nil
        DebugLog.shared.log("PRAYER stopped")
        #endif
    }

    #if DEBUG
    func clearDebugLog() {
        debugLog = []
    }
    #endif

    private func startPrayerPlayback() {
        guard let steps = buildPrayerSteps() else { return }

        playTask?.cancel()
        playTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.restoreIdleTimerIfNeeded()
                self.isPraying = false
                self.isPreparingAudio = false
                self.playTask = nil
            }

            do {
                self.isPraying = true
                self.holdIdleTimer()
                #if DEBUG
                try await self.sequencePlayer.play(
                    steps: steps,
                    onPromptChanged: { [weak self] prompt in
                        Task { @MainActor in
                            self?.currentPrompt = prompt
                        }
                    },
                    onDebugStatusChanged: { [weak self] status in
                        Task { @MainActor in
                            guard let self else { return }
                            self.latestDebugStatus = status
                            let formatted = Self.format(debugStatus: status)
                            self.debugText = formatted
                            self.appendDebugLine(formatted)
                            if let eventLine = Self.eventLineForDebugLog(status) {
                                DebugLog.shared.log(eventLine)
                            }
                        }
                    }
                )
                #else
                try await self.sequencePlayer.play(steps: steps) { [weak self] prompt in
                    Task { @MainActor in
                        self?.currentPrompt = prompt
                    }
                }
                #endif
            } catch is CancellationError {
            } catch {
                if self.errorMessage == nil || self.errorMessage?.isEmpty == true {
                    self.errorMessage = error.localizedDescription
                }
                #if DEBUG
                DebugLog.shared.log("PRAYER error \(error.localizedDescription)")
                #endif
            }
        }
    }

    private func buildPrayerSteps() -> [PrayerSequenceStep]? {
        let sequence = RosarySequenceBuilder.makeStandardRosary()
        var steps: [PrayerSequenceStep] = []
        steps.reserveCapacity(sequence.count * 2)

        let turnPolicy = PrayerTurnPolicy(style: interactiveStyle)
        let waitConfig = InteractiveCalibrationHeuristics.utteranceConfig(
            for: interactiveCalibration,
            startTimeoutSec: interactivePolicy.userResponseTimeoutSec
        )
        #if DEBUG
        DebugLog.shared.log(
            String(
                format: "CALIBRATION session start=%.4f continue=%.4f silence=%.2f timeout=%.2f",
                waitConfig.speechStartThreshold,
                waitConfig.speechContinueThreshold,
                waitConfig.completionSilenceSec,
                waitConfig.startTimeoutSec
            )
        )
        #endif

        for prayerType in sequence {
            let segment = prayerType.segmentDefinition

            guard let url = resolver.resolve(personID: personID, token: segment.token) else {
                errorMessage = "Missing audio for \(segment.token) (.m4a or .wav)."
                return nil
            }
            let asset = AudioAssetRef(id: "\(personID):\(segment.token)", url: url)

            if !isInteractive {
                steps.append(.play(asset: asset, prompt: segment.listenPrompt))
                steps.append(.pause(ms: segment.pauseAfterMs, prompt: nil))
                continue
            }

            switch turnPolicy.speaker(for: segment.role) {
            case .partner:
                steps.append(.play(asset: asset, prompt: segment.listenPrompt))
                steps.append(.pause(ms: segment.pauseAfterMs, prompt: nil))
            case .user, .prayTogether:
                let activePrompt = segment.role == .unison ? segment.togetherPrompt : segment.yourTurnPrompt
                let fallbackPrompt = PrayerPrompt(title: "Continuing for you", text: segment.promptText)
                if interactivePolicy.fallbackToSeedEnabled {
                    steps.append(
                        .waitForUtteranceOrFallback(
                            waitConfig,
                            fallbackAsset: asset,
                            prompt: activePrompt,
                            fallbackPrompt: fallbackPrompt
                        )
                    )
                } else {
                    steps.append(.waitForUtterance(waitConfig, prompt: activePrompt))
                }
            }
        }

        return steps
    }

    private func holdIdleTimer() {
        guard !isHoldingIdleTimer else { return }
        idleTimerController.disableIdleTimer()
        isHoldingIdleTimer = true
    }

    private func restoreIdleTimerIfNeeded() {
        guard isHoldingIdleTimer else { return }
        idleTimerController.restoreIdleTimer()
        isHoldingIdleTimer = false
    }

    #if DEBUG
    private func appendDebugLine(_ line: String) {
        let timestamp = Self.debugTimestampFormatter.string(from: Date())
        debugLog.append("[\(timestamp)] \(line)")
        if debugLog.count > 120 {
            debugLog.removeFirst(debugLog.count - 120)
        }
    }

    private static let debugTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter
    }()

    private static func format(debugStatus: PrayDebugStatus) -> String {
        let phaseText: String
        switch debugStatus.listenerPhase {
        case .userTurnWaitingForSpeechStart(let rms, let startThreshold, let elapsed, let timeout):
            phaseText = String(
                format: "USER_TURN waitingForSpeechStart rms=%.4f start=%.4f t=%.2f/%.2f",
                rms,
                startThreshold,
                elapsed,
                timeout
            )
        case .userTurnSpeechStarted:
            phaseText = "USER_TURN speechStarted"
        case .userTurnSpeaking(let rms, let continueThreshold):
            phaseText = String(
                format: "USER_TURN speaking rms=%.4f continue=%.4f",
                rms,
                continueThreshold
            )
        case .userTurnWaitingForSpeechEnd(let rms, let silenceElapsed, let required, let continueThreshold):
            phaseText = String(
                format: "USER_TURN waitingForSpeechEnd rms=%.4f silence=%.2f/%.2f continue=%.4f",
                rms,
                silenceElapsed,
                required,
                continueThreshold
            )
        case .userTurnCompleted:
            phaseText = "USER_TURN completed"
        case .userTurnStartTimedOut:
            phaseText = "USER_TURN startTimedOut -> fallback"
        case .userTurnMaxDurationExceeded:
            phaseText = "USER_TURN maxDurationExceeded -> continue"
        case .idle:
            phaseText = "idle"
        case .waitingForSpeech(let rms, let startThreshold, let endThreshold):
            phaseText = String(
                format: "waiting rms=%.4f start=%.4f end=%.4f",
                rms,
                startThreshold,
                endThreshold
            )
        case .speechDetected(let rms):
            phaseText = String(format: "speech detected rms=%.4f", rms)
        case .speaking(
            let rms,
            let endThreshold,
            let speechDuration,
            let silenceAccumulated,
            let silenceRequired,
            let softSilenceRequired,
            let softMinSpeechSec
        ):
            phaseText = String(
                format: "speaking rms=%.4f end=%.4f silence=%.2f/%.2f speech=%.2fs soft=%.2f@%.2fs",
                rms,
                endThreshold,
                silenceAccumulated,
                silenceRequired,
                speechDuration,
                softSilenceRequired,
                softMinSpeechSec
            )
        case .silenceCountdown(
            let rms,
            let elapsed,
            let required,
            let speechDuration,
            let softSilenceRequired,
            let softMinSpeechSec
        ):
            phaseText = String(
                format: "silence rms=%.4f silence=%.2f/%.2f speech=%.2fs soft=%.2f@%.2fs",
                rms,
                elapsed,
                required,
                speechDuration,
                softSilenceRequired,
                softMinSpeechSec
            )
        case .completed(let reason):
            phaseText = "completed (\(reason))"
        case .timedOut:
            phaseText = "timed out"
        case .failed(let message):
            phaseText = "failed: \(message)"
        }
        return "\(debugStatus.stepSummary) • \(phaseText)"
    }

    private static func eventLineForDebugLog(_ status: PrayDebugStatus) -> String? {
        switch status.listenerPhase {
        case .userTurnWaitingForSpeechStart(let rms, let startThreshold, let elapsed, let timeout):
            return String(
                format: "USER_TURN waitingForSpeechStart MIC level=%.4f startThreshold=%.4f start=%.2f/%.2f",
                rms,
                startThreshold,
                elapsed,
                timeout
            )
        case .userTurnSpeechStarted:
            return "USER_TURN speechStarted"
        case .userTurnSpeaking(let rms, let continueThreshold):
            return String(
                format: "USER_TURN speaking MIC level=%.4f continueThreshold=%.4f",
                rms,
                continueThreshold
            )
        case .userTurnWaitingForSpeechEnd(let rms, let silenceElapsed, let required, let continueThreshold):
            return String(
                format: "USER_TURN waitingForSpeechEnd MIC level=%.4f silence=%.2f/%.2f continueThreshold=%.4f",
                rms,
                silenceElapsed,
                required,
                continueThreshold
            )
        case .userTurnCompleted:
            return "USER_TURN completedByUser"
        case .userTurnStartTimedOut:
            return "USER_TURN startTimedOut -> fallback"
        case .userTurnMaxDurationExceeded:
            return "USER_TURN maxDurationExceeded -> continue"
        case .failed(let message):
            return "USER_TURN failed \(message)"
        default:
            return nil
        }
    }
    #endif
}

private extension PrayerType {
    var segmentDefinition: PrayerSegmentDefinition {
        switch self {
        case .apostlesCreedLead:
            return PrayerSegmentDefinition(
                token: "apostles_creed_lead",
                pauseAfterMs: 250,
                promptText: "I believe in God, the Father almighty...",
                role: .lead
            )
        case .apostlesCreedResponse:
            return PrayerSegmentDefinition(
                token: "apostles_creed_response",
                pauseAfterMs: 400,
                promptText: "I believe in God, the Father almighty...",
                role: .response
            )
        case .ourFatherLead:
            return PrayerSegmentDefinition(
                token: "our_father_lead",
                pauseAfterMs: 400,
                promptText: "Our Father, who art in heaven...",
                role: .lead
            )
        case .ourFatherResponse:
            return PrayerSegmentDefinition(
                token: "our_father_response",
                pauseAfterMs: 400,
                promptText: "Our Father, who art in heaven...",
                role: .response
            )
        case .hailMaryLead:
            return PrayerSegmentDefinition(
                token: "hail_lead",
                pauseAfterMs: 400,
                promptText: "Hail Mary, full of grace...",
                role: .lead
            )
        case .hailMaryResponse:
            return PrayerSegmentDefinition(
                token: "hail_response",
                pauseAfterMs: 0,
                promptText: "Hail Mary, full of grace...",
                role: .response
            )
        case .gloryBeLead:
            return PrayerSegmentDefinition(
                token: "glory_be_lead",
                pauseAfterMs: 300,
                promptText: "Glory be to the Father...",
                role: .lead
            )
        case .gloryBeResponse:
            return PrayerSegmentDefinition(
                token: "glory_be_response",
                pauseAfterMs: 300,
                promptText: "Glory be to the Father...",
                role: .response
            )
        case .fatima:
            return PrayerSegmentDefinition(
                token: "fatima",
                pauseAfterMs: 300,
                promptText: "O my Jesus, forgive us our sins...",
                role: .unison
            )
        case .hailHolyQueenLead:
            return PrayerSegmentDefinition(
                token: "hail_holy_queen_lead",
                pauseAfterMs: 400,
                promptText: "Hail, holy Queen, Mother of mercy...",
                role: .lead
            )
        case .hailHolyQueenResponse:
            return PrayerSegmentDefinition(
                token: "hail_holy_queen_response",
                pauseAfterMs: 0,
                promptText: "Hail, holy Queen, Mother of mercy...",
                role: .response
            )
        }
    }
}

private struct PrayerSegmentDefinition {
    let token: String
    let pauseAfterMs: Int
    let promptText: String
    let role: PrayerSegmentRole

    var listenPrompt: PrayerPrompt {
        PrayerPrompt(title: "Listen", text: promptText)
    }

    var yourTurnPrompt: PrayerPrompt {
        PrayerPrompt(title: "Your turn", text: promptText)
    }

    var togetherPrompt: PrayerPrompt {
        PrayerPrompt(title: "Pray together", text: promptText)
    }
}
