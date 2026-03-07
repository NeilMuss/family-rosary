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
    #endif
    @Published var errorMessage: String?
    @Published var showMicrophoneDeniedAlert = false

    private let personID: String
    private let sequencePlayer: PrayerSequencePlaying
    private let resolver: AudioFileResolving
    private let microphonePermissionClient: MicrophonePermissionClient
    private var playTask: Task<Void, Never>?
    private var isStartingPrayer = false

    init(
        personID: String = "dad",
        sequencePlayer: PrayerSequencePlaying,
        resolver: AudioFileResolving,
        microphonePermissionClient: MicrophonePermissionClient
    ) {
        self.personID = personID
        self.sequencePlayer = sequencePlayer
        self.resolver = resolver
        self.microphonePermissionClient = microphonePermissionClient
    }

    func onTapPray() {
        guard !isPraying, !isStartingPrayer else { return }
        errorMessage = nil
        currentPrompt = nil
        #if DEBUG
        debugText = ""
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
                return
            }

            self.startPrayerPlayback()
        }
    }

    func onTapStop() {
        playTask?.cancel()
        sequencePlayer.stop()
        isPraying = false
        isPreparingAudio = false
        currentPrompt = nil
        #if DEBUG
        debugText = ""
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
                self.isPraying = false
                self.isPreparingAudio = false
                self.playTask = nil
            }

            do {
                self.isPraying = true
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
                            let formatted = Self.format(debugStatus: status)
                            self.debugText = formatted
                            self.appendDebugLine(formatted)
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
            }
        }
    }

    private func buildPrayerSteps() -> [PrayerSequenceStep]? {
        let planItems: [RosaryPlanItem]
        if isInteractive {
            planItems = RosaryDecadePlanBuilder().build(interactive: true)
        } else {
            planItems = RosarySequenceBuilder
                .makeStandardRosary()
                .map { $0.planItem }
        }
        var steps: [PrayerSequenceStep] = []
        steps.reserveCapacity(planItems.count * 2)

        for item in planItems {
            switch item {
            case .play(let token, let pauseAfterMs, let prompt):
                guard let url = resolver.resolve(personID: personID, token: token) else {
                    errorMessage = "Missing audio for \(token) (.m4a or .wav)."
                    return nil
                }
                let asset = AudioAssetRef(id: "\(personID):\(token)", url: url)
                steps.append(.play(asset: asset, prompt: prompt))
                steps.append(.pause(ms: pauseAfterMs, prompt: prompt))
            case .waitForUtterance(let config, let prompt):
                steps.append(.waitForUtterance(config, prompt: prompt))
            }
        }

        return steps
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
    #endif
}

private extension PrayerType {
    var planItem: RosaryPlanItem {
        switch self {
        case .apostlesCreedLead:
            return .play(
                token: "apostles_creed_lead",
                pauseAfterMs: 250,
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        case .apostlesCreedResponse:
            return .play(
                token: "apostles_creed_response",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        case .ourFatherLead:
            return .play(
                token: "our_father_lead",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "Our Father, who art in heaven...")
            )
        case .ourFatherResponse:
            return .play(
                token: "our_father_response",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "Our Father, who art in heaven...")
            )
        case .hailMaryLead:
            return .play(
                token: "hail_lead",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "Hail Mary, full of grace...")
            )
        case .hailMaryResponse:
            return .play(
                token: "hail_response",
                pauseAfterMs: 0,
                prompt: PrayerPrompt(title: "Listen", text: "Hail Mary, full of grace...")
            )
        case .gloryBeLead:
            return .play(
                token: "glory_be_lead",
                pauseAfterMs: 300,
                prompt: PrayerPrompt(title: "Listen", text: "Glory be to the Father...")
            )
        case .gloryBeResponse:
            return .play(
                token: "glory_be_response",
                pauseAfterMs: 300,
                prompt: PrayerPrompt(title: "Listen", text: "Glory be to the Father...")
            )
        case .fatima:
            return .play(
                token: "fatima",
                pauseAfterMs: 300,
                prompt: PrayerPrompt(title: "Listen", text: "O my Jesus, forgive us our sins...")
            )
        case .hailHolyQueenLead:
            return .play(
                token: "hail_holy_queen_lead",
                pauseAfterMs: 400,
                prompt: PrayerPrompt(title: "Listen", text: "Hail, holy Queen, Mother of mercy...")
            )
        case .hailHolyQueenResponse:
            return .play(
                token: "hail_holy_queen_response",
                pauseAfterMs: 0,
                prompt: PrayerPrompt(title: "Listen", text: "Hail, holy Queen, Mother of mercy...")
            )
        }
    }
}
