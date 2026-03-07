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

    private let prayViewModel: PrayViewModel
    private let prayerMode: PrayerMode
    private let prayerStyle: PrayerStyle
    private let onEndRosary: () -> Void
    private let displayMapper = PrayerSessionDisplayMapper()

    private var cancellables: Set<AnyCancellable> = []
    private var promptEventCount = 0

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
        promptEventCount = 0
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
    }

    private func handlePrompt(_ prompt: PrayerPrompt?) {
        guard let prompt else { return }

        promptEventCount += 1
        let rosaryStepIndex = max(1, (promptEventCount + 1) / 2)

        displayState = displayMapper.map(
            rosaryStepIndex: rosaryStepIndex,
            prayerType: displayMapper.prayerType(for: prompt.text),
            mode: prayerMode,
            style: prayerStyle,
            promptTitle: prompt.title
        )
    }
}
