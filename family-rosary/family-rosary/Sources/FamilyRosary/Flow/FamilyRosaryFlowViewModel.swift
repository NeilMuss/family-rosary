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
    private var pendingCalibration: InteractiveCalibration?

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
            pendingCalibration = nil
            microphoneCheckViewModel = root.makeMicrophoneCheckViewModel(
                onStartPrayer: { [weak self] calibration in
                    self?.startFromMicrophoneCheck(calibration: calibration)
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

    private func startFromMicrophoneCheck(calibration: InteractiveCalibration?) {
        guard let request = pendingStartRequest else {
            backToSetup()
            return
        }

        pendingCalibration = calibration
        pendingStartRequest = nil
        microphoneCheckViewModel = nil
        startPraying(request: request, calibration: pendingCalibration)
    }

    private func backToSetup() {
        pendingStartRequest = nil
        pendingCalibration = nil
        microphoneCheckViewModel = nil
        prayerModeViewModel = nil
        screen = .setup
    }

    private func startPraying(
        request: StartRosaryRequest,
        calibration: InteractiveCalibration? = nil
    ) {
        let prayViewModel = root.makePrayViewModel(personID: request.partnerID)
        prayViewModel.interactiveCalibration = calibration
        let prayerModeViewModel = PrayerModeViewModel(
            prayViewModel: prayViewModel,
            preferencesStore: root.makeRosaryPreferencesStore(),
            prayerMode: request.prayerMode,
            prayerStyle: request.prayerStyle,
            onEndRosary: { [weak self] in
                self?.endRosarySession()
            }
        )

        pendingCalibration = nil
        self.prayerModeViewModel = prayerModeViewModel
        screen = .praying
        prayerModeViewModel.start()
    }

    private func endRosarySession() {
        backToSetup()
    }
}
