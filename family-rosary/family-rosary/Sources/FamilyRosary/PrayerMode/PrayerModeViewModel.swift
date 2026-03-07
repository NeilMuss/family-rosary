import Foundation
import Combine

@MainActor
final class PrayerModeViewModel: ObservableObject {
    @Published private(set) var displayState = PrayerSessionDisplayState(
        sectionTitle: "Opening Prayers",
        prayerTitle: "Apostles' Creed",
        countText: nil,
        rolePrompt: nil,
        isPaused: false
    )
    @Published var errorMessage: String?
    #if DEBUG
    @Published private(set) var prayerDebugState: PrayerDebugState?
    #endif

    private let prayViewModel: PrayViewModel
    private let prayerMode: PrayerMode
    private let prayerStyle: PrayerStyle
    private let onEndRosary: () -> Void
    private let displayMapper = PrayerSessionDisplayMapper()

    private var cancellables: Set<AnyCancellable> = []
    private var currentRosaryStepIndex = 1
    private var hasSeenPrimaryPrompt = false
    #if DEBUG
    private var didStartSpeaking = false
    private var lastMicLevel: Float = 0
    private var lastStartTimeoutText = "-"
    private var lastSilenceText = "-"
    #endif

    init(
        prayViewModel: PrayViewModel,
        prayerMode: PrayerMode,
        prayerStyle: PrayerStyle,
        onEndRosary: @escaping () -> Void
    ) {
        self.prayViewModel = prayViewModel
        self.prayerMode = prayerMode
        self.prayerStyle = prayerStyle
        self.onEndRosary = onEndRosary
        bind()
    }

    func start() {
        prayViewModel.isInteractive = (prayerMode == .interactive)
        displayState = displayMapper.map(
            rosaryStepIndex: 1,
            prayerType: .apostlesCreed,
            mode: prayerMode,
            style: prayerStyle,
            promptTitle: nil
        )
        currentRosaryStepIndex = 1
        hasSeenPrimaryPrompt = false
        prayViewModel.interactiveStyle = prayerStyle
        #if DEBUG
        didStartSpeaking = false
        lastMicLevel = 0
        lastStartTimeoutText = "-"
        lastSilenceText = "-"
        prayerDebugState = buildPrayerDebugState(listenerStateText: "idle")
        #endif
        prayViewModel.onTapPray()
    }

    func onTapPauseResume() {
        if displayState.isPaused {
            start()
            return
        }

        prayViewModel.onTapStop()
        displayState = PrayerSessionDisplayState(
            sectionTitle: displayState.sectionTitle,
            prayerTitle: displayState.prayerTitle,
            countText: displayState.countText,
            rolePrompt: displayState.rolePrompt,
            isPaused: true
        )
    }

    func onTapEndRosary() {
        prayViewModel.onTapStop()
        onEndRosary()
    }

    var pauseButtonTitle: String {
        displayState.isPaused ? "Resume" : "Pause"
    }

    private func bind() {
        prayViewModel.$currentPrompt
            .sink { [weak self] prompt in
                self?.handlePrompt(prompt)
            }
            .store(in: &cancellables)

        prayViewModel.$errorMessage
            .sink { [weak self] error in
                self?.errorMessage = error
            }
            .store(in: &cancellables)

        #if DEBUG
        prayViewModel.$latestDebugStatus
            .sink { [weak self] status in
                self?.handleDebugStatus(status)
            }
            .store(in: &cancellables)
        #endif
    }

    private func handlePrompt(_ prompt: PrayerPrompt?) {
        guard let prompt else { return }

        if prompt.title != "Continuing for you" {
            if !hasSeenPrimaryPrompt {
                hasSeenPrimaryPrompt = true
                currentRosaryStepIndex = 1
            } else {
                currentRosaryStepIndex += 1
            }
        }

        displayState = displayMapper.map(
            rosaryStepIndex: currentRosaryStepIndex,
            prayerType: displayMapper.prayerType(for: prompt.text),
            mode: prayerMode,
            style: prayerStyle,
            promptTitle: prompt.title
        )
        #if DEBUG
        prayerDebugState = buildPrayerDebugState(listenerStateText: prayerDebugState?.listenerStateText ?? "idle")
        #endif
    }

    #if DEBUG
    private func handleDebugStatus(_ status: PrayDebugStatus?) {
        guard let status else { return }

        let listenerStateText: String
        switch status.listenerPhase {
        case .idle:
            listenerStateText = "idle"
        case .userTurnWaitingForSpeechStart(let rms, _, let elapsed, let timeout):
            didStartSpeaking = false
            lastMicLevel = rms
            lastStartTimeoutText = String(format: "%.2fs / %.2fs", elapsed, timeout)
            lastSilenceText = "-"
            listenerStateText = "waitingForSpeechStart"
        case .userTurnSpeechStarted:
            didStartSpeaking = true
            listenerStateText = "speechStarted"
        case .userTurnSpeaking(let rms):
            didStartSpeaking = true
            lastMicLevel = rms
            listenerStateText = "speaking"
        case .userTurnWaitingForSpeechEnd(let rms, let silenceElapsed, let required):
            didStartSpeaking = true
            lastMicLevel = rms
            lastSilenceText = String(format: "%.2fs / %.2fs", silenceElapsed, required)
            listenerStateText = "waitingForSpeechEnd"
        case .userTurnCompleted:
            listenerStateText = "completed"
        case .userTurnStartTimedOut:
            listenerStateText = "startTimedOut -> fallback"
        case .userTurnMaxDurationExceeded:
            listenerStateText = "maxDurationExceeded -> continue"
        case .waitingForSpeech(let rms, _, _):
            lastMicLevel = rms
            listenerStateText = "waitingForSpeech(legacy)"
        case .speechDetected(let rms):
            lastMicLevel = rms
            listenerStateText = "speechDetected(legacy)"
        case .speaking(let rms, _, _, _, _, _, _):
            lastMicLevel = rms
            listenerStateText = "speaking(legacy)"
        case .silenceCountdown(let rms, let elapsed, let required, _, _, _):
            lastMicLevel = rms
            lastSilenceText = String(format: "%.2fs / %.2fs", elapsed, required)
            listenerStateText = "silenceCountdown(legacy)"
        case .completed(let reason):
            listenerStateText = "completed(\(reason))"
        case .timedOut:
            listenerStateText = "timedOut(legacy)"
        case .failed(let message):
            listenerStateText = "failed: \(message)"
        }

        prayerDebugState = buildPrayerDebugState(listenerStateText: listenerStateText)
    }

    private func buildPrayerDebugState(listenerStateText: String) -> PrayerDebugState {
        let modeText = prayerMode == .interactive ? "interactive" : "automatic"
        let roleText = displayState.rolePrompt ?? "-"
        let fallbackArmed = prayerMode == .interactive && !didStartSpeaking
        return PrayerDebugState(
            modeText: "mode: \(modeText)",
            roleText: "role: \(roleText)",
            listenerStateText: "listener: \(listenerStateText)",
            micLevelText: String(format: "micLevel: %.4f", lastMicLevel),
            didStartSpeakingText: "didStartSpeaking: \(didStartSpeaking ? "yes" : "no")",
            fallbackArmedText: "fallbackArmed: \(fallbackArmed ? "yes" : "no")",
            startTimeoutText: "startTimeout: \(lastStartTimeoutText)",
            silenceText: "silence: \(lastSilenceText)",
            prayerText: "prayer: \(displayState.prayerTitle)"
        )
    }
    #endif
}
