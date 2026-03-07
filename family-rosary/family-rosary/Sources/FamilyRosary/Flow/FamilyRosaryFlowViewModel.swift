import Foundation
import Combine

@MainActor
final class FamilyRosaryFlowViewModel: ObservableObject {
    enum Screen {
        case setup
        case praying
    }

    @Published private(set) var screen: Screen = .setup
    @Published private(set) var prayerModeViewModel: PrayerModeViewModel?

    let setupViewModel: SetupViewModel

    private let root: AppCompositionRoot

    init(root: AppCompositionRoot) {
        self.root = root

        self.setupViewModel = SetupViewModel(
            availablePartners: root.makeAvailablePrayerPartners(),
            preferencesStore: root.makeRosaryPreferencesStore(),
            onStartPraying: { _ in }
        )
        self.setupViewModel.setOnStartPraying { [weak self] request in
            self?.startPraying(request: request)
        }
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
        prayerModeViewModel = nil
        screen = .setup
    }
}
