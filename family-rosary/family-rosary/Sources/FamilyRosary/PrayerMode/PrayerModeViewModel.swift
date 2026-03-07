import Foundation
import Combine

@MainActor
final class PrayerModeViewModel: ObservableObject {
    @Published private(set) var displayState = PrayerSessionDisplayState(
        sectionTitle: "Opening Prayers",
        prayerTitle: "Apostles' Creed",
        countText: "0 / 139",
        roleText: "Pray together",
        isPaused: false
    )
    @Published var errorMessage: String?

    private let prayViewModel: PrayViewModel
    private let prayerStyle: PrayerStyle
    private let onEndRosary: () -> Void

    private var cancellables: Set<AnyCancellable> = []
    private var promptStepCount = 0

    init(
        prayViewModel: PrayViewModel,
        prayerStyle: PrayerStyle,
        onEndRosary: @escaping () -> Void
    ) {
        self.prayViewModel = prayViewModel
        self.prayerStyle = prayerStyle
        self.onEndRosary = onEndRosary
        bind()
    }

    func start() {
        displayState = PrayerSessionDisplayState(
            sectionTitle: "Opening Prayers",
            prayerTitle: "Apostles' Creed",
            countText: "0 / 139",
            roleText: roleText(forPrayerNumber: 1, prayerTitle: "Apostles' Creed"),
            isPaused: false
        )
        promptStepCount = 0
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
            roleText: displayState.roleText,
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

        promptStepCount += 1
        let prayerNumber = max(1, (promptStepCount + 1) / 2)
        let prayerTitle = prayerTitle(for: prompt)

        displayState = PrayerSessionDisplayState(
            sectionTitle: sectionTitle(forPrayerNumber: prayerNumber),
            prayerTitle: prayerTitle,
            countText: "\(prayerNumber) / 139",
            roleText: roleText(forPrayerNumber: prayerNumber, prayerTitle: prayerTitle),
            isPaused: false
        )
    }

    private func sectionTitle(forPrayerNumber prayerNumber: Int) -> String {
        if prayerNumber <= 12 {
            return "Opening Prayers"
        }
        if prayerNumber >= 138 {
            return "Closing Prayers"
        }
        return "1st Decade"
    }

    private func prayerTitle(for prompt: PrayerPrompt) -> String {
        let text = prompt.text

        if text.hasPrefix("I believe in God") {
            return "Apostles' Creed"
        }
        if text.hasPrefix("Our Father") {
            return "Our Father"
        }
        if text.hasPrefix("Hail Mary") {
            return "Hail Mary"
        }
        if text.hasPrefix("Glory be") {
            return "Glory Be"
        }
        if text.hasPrefix("O my Jesus") {
            return "Fatima Prayer"
        }
        if text.hasPrefix("Hail, holy Queen") {
            return "Hail Holy Queen"
        }

        return "Prayer"
    }

    private func roleText(forPrayerNumber prayerNumber: Int, prayerTitle: String) -> String {
        if prayerTitle == "Fatima Prayer" {
            return "Pray together"
        }

        switch prayerStyle {
        case .alwaysLead:
            return "Now your turn"
        case .alwaysRespond:
            return "Now listen"
        case .alternateIStart:
            return prayerNumber.isMultiple(of: 2) ? "Now listen" : "Now your turn"
        case .alternateIRespond:
            return prayerNumber.isMultiple(of: 2) ? "Now your turn" : "Now listen"
        }
    }
}
