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
    @Published var isCandleBackgroundEnabled: Bool

    private let prayViewModel: PrayViewModel
    private let preferencesStore: RosaryPreferencesStore
    private let prayerMode: PrayerMode
    private let prayerStyle: PrayerStyle
    private let onEndRosary: () -> Void
    private let displayMapper = PrayerSessionDisplayMapper()
    private let rosarySequence = RosarySequenceBuilder.makeStandardRosary()

    private var cancellables: Set<AnyCancellable> = []
    private var currentRosaryStepIndex = 1
    private var hasSeenPrimaryPrompt = false
    private var pendingStartStepIndex = 1

    init(
        prayViewModel: PrayViewModel,
        preferencesStore: RosaryPreferencesStore,
        prayerMode: PrayerMode,
        prayerStyle: PrayerStyle,
        onEndRosary: @escaping () -> Void
    ) {
        self.prayViewModel = prayViewModel
        self.preferencesStore = preferencesStore
        self.prayerMode = prayerMode
        self.prayerStyle = prayerStyle
        self.onEndRosary = onEndRosary
        self.isCandleBackgroundEnabled = preferencesStore.loadCandleBackgroundEnabled()
        bind()
    }

    var shouldShowCandleBackgroundAtFullEffect: Bool {
        displayState.isPaused == false
    }

    func start() {
        startPrayer(atRosaryStepIndex: 1)
    }

    // Testing affordance: advances by restarting the existing playback path from the
    // next prayer segment instead of introducing a parallel sequence controller.
    func onTapNextPrayerSegment() {
        let nextStepIndex = currentRosaryStepIndex + 1
        guard nextStepIndex <= rosarySequence.count else {
            onTapEndRosary()
            return
        }

        prayViewModel.onTapStop()
        startPrayer(atRosaryStepIndex: nextStepIndex)
    }

    private func startPrayer(atRosaryStepIndex stepIndex: Int) {
        prayViewModel.isInteractive = (prayerMode == .interactive)
        let boundedStepIndex = min(max(1, stepIndex), rosarySequence.count)
        displayState = displayMapper.map(
            rosaryStepIndex: boundedStepIndex,
            prayerType: sessionPrayerType(for: rosarySequence[boundedStepIndex - 1]),
            mode: prayerMode,
            style: prayerStyle,
            promptTitle: nil
        )
        currentRosaryStepIndex = boundedStepIndex
        pendingStartStepIndex = boundedStepIndex
        hasSeenPrimaryPrompt = false
        prayViewModel.interactiveStyle = prayerStyle
        #if DEBUG
        DebugLog.shared.log("PRAYER \(displayState.prayerTitle)")
        #endif
        prayViewModel.onTapPray(startingAtPrayerIndex: boundedStepIndex - 1)
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

    func setCandleBackgroundEnabled(_ enabled: Bool) {
        guard isCandleBackgroundEnabled != enabled else { return }
        isCandleBackgroundEnabled = enabled
        preferencesStore.saveCandleBackgroundEnabled(enabled)
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
    }

    private func handlePrompt(_ prompt: PrayerPrompt?) {
        guard let prompt else { return }

        if prompt.title != "Continuing for you" {
            if !hasSeenPrimaryPrompt {
                hasSeenPrimaryPrompt = true
                currentRosaryStepIndex = pendingStartStepIndex
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
        DebugLog.shared.log("NEXT_SEGMENT \(displayState.prayerTitle)")
        DebugLog.shared.log("PRAYER \(displayState.prayerTitle)")
        if let rolePrompt = displayState.rolePrompt {
            switch rolePrompt {
            case "Now your turn":
                DebugLog.shared.log("ROLE userTurn")
            case "Now listen":
                DebugLog.shared.log("ROLE listen")
            case "Pray together":
                DebugLog.shared.log("ROLE prayTogether")
            default:
                break
            }
        }
        #endif
    }

    private func sessionPrayerType(for prayerType: PrayerType) -> SessionPrayerType {
        switch prayerType {
        case .apostlesCreedLead, .apostlesCreedResponse:
            return .apostlesCreed
        case .ourFatherLead, .ourFatherResponse:
            return .ourFather
        case .hailMaryLead, .hailMaryResponse:
            return .hailMary
        case .gloryBeLead, .gloryBeResponse:
            return .gloryBe
        case .fatima:
            return .fatima
        case .hailHolyQueenOpeningLead, .hailHolyQueenResponse, .hailHolyQueenClosingLead:
            return .hailHolyQueen
        }
    }
}
