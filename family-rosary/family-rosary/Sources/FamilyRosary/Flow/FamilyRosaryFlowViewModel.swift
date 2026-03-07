import Foundation
import Combine

@MainActor
final class FamilyRosaryFlowViewModel: ObservableObject {
    enum Screen {
        case setup
        case microphoneCheck
        case praying
    }

    @Published private(set) var screen: Screen = .setup
    @Published private(set) var microphoneCheckViewModel: MicrophoneCheckViewModel?
    @Published private(set) var prayerModeViewModel: PrayerModeViewModel?

    let setupViewModel: SetupViewModel

    private let root: AppCompositionRoot
    private var pendingStartRequest: StartRosaryRequest?

    init(root: AppCompositionRoot) {
        self.root = root

        self.setupViewModel = SetupViewModel(
            availablePartners: root.makeAvailablePrayerPartners(),
            preferencesStore: root.makeRosaryPreferencesStore(),
            onStartPraying: { _ in }
        )
        self.setupViewModel.setOnStartPraying { [weak self] request in
            self?.onStartRequested(request: request)
        }
    }

    private func onStartRequested(request: StartRosaryRequest) {
        if request.prayerMode == .interactive {
            pendingStartRequest = request
            microphoneCheckViewModel = root.makeMicrophoneCheckViewModel(
                onStartPrayer: { [weak self] in
                    self?.startFromMicrophoneCheck()
                },
                onBack: { [weak self] in
                    self?.backToSetup()
                }
            )
            screen = .microphoneCheck
            return
        }

        startPraying(request: request)
    }

    private func startFromMicrophoneCheck() {
        guard let request = pendingStartRequest else {
            backToSetup()
            return
        }

        pendingStartRequest = nil
        microphoneCheckViewModel = nil
        startPraying(request: request)
    }

    private func backToSetup() {
        pendingStartRequest = nil
        microphoneCheckViewModel = nil
        prayerModeViewModel = nil
        screen = .setup
    }

    private func startPraying(request: StartRosaryRequest) {
        let prayerModeViewModel = PrayerModeViewModel(
            prayViewModel: root.makePrayViewModel(personID: request.partnerID),
            prayerMode: request.prayerMode,
            prayerStyle: request.prayerStyle,
            onEndRosary: { [weak self] in
                self?.endRosarySession()
            }
        )

        self.prayerModeViewModel = prayerModeViewModel
        screen = .praying
        prayerModeViewModel.start()
    }

    private func endRosarySession() {
        backToSetup()
    }
}
