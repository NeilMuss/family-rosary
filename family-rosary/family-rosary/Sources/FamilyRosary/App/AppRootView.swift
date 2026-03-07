import SwiftUI

struct AppRootView: View {
    @StateObject private var viewModel: FamilyRosaryFlowViewModel

    init(root: AppCompositionRoot) {
        _viewModel = StateObject(wrappedValue: root.makeFamilyRosaryFlowViewModel())
    }

    var body: some View {
        Group {
            switch viewModel.screen {
            case .setup:
                SetupView(viewModel: viewModel.setupViewModel)
            case .praying:
                if let prayerModeViewModel = viewModel.prayerModeViewModel {
                    PrayerModeView(viewModel: prayerModeViewModel)
                } else {
                    Color.white
                }
            }
        }
    }
}
