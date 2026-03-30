import SwiftUI

struct AppRootView: View {
    @StateObject private var viewModel: FamilyRosaryFlowViewModel
    @StateObject private var shareImportPreviewViewModel: ShareImportPreviewViewModel

    init(root: AppCompositionRoot) {
        _viewModel = StateObject(wrappedValue: root.makeFamilyRosaryFlowViewModel())
        _shareImportPreviewViewModel = StateObject(wrappedValue: root.makeShareImportPreviewViewModel())
    }

    var body: some View {
        Group {
            switch viewModel.screen {
            case .setup:
                SetupView(viewModel: viewModel.setupViewModel)
            case .microphoneCheck:
                if let microphoneCheckViewModel = viewModel.microphoneCheckViewModel {
                    MicrophoneCheckView(viewModel: microphoneCheckViewModel)
                } else {
                    Color.white
                }
            case .praying:
                if let prayerModeViewModel = viewModel.prayerModeViewModel {
                    PrayerModeView(viewModel: prayerModeViewModel)
                } else {
                    Color.white
                }
            }
        }
        .onOpenURL { url in
            shareImportPreviewViewModel.handleIncomingURL(url)
        }
        .sheet(isPresented: $shareImportPreviewViewModel.isPresented) {
            ShareImportPreviewSheet(viewModel: shareImportPreviewViewModel)
        }
    }
}
