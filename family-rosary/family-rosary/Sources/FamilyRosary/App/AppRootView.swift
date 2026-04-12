import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppRootView: View {
    private let root: AppCompositionRoot
    @StateObject private var viewModel: FamilyRosaryFlowViewModel
    @StateObject private var shareImportPreviewViewModel: ShareImportPreviewViewModel
    @StateObject private var sharedInboxScanCoordinator: SharedInboxScanCoordinator

    init(root: AppCompositionRoot) {
        self.root = root
        _viewModel = StateObject(wrappedValue: root.makeFamilyRosaryFlowViewModel())
        _shareImportPreviewViewModel = StateObject(wrappedValue: root.makeShareImportPreviewViewModel())
        _sharedInboxScanCoordinator = StateObject(wrappedValue: root.makeSharedInboxScanCoordinator())
    }

    var body: some View {
        Group {
            switch viewModel.screen {
            case .setup:
                SetupView(
                    viewModel: viewModel.setupViewModel,
                    sharedInboxScanCoordinator: sharedInboxScanCoordinator
                )
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
        .task {
            sharedInboxScanCoordinator.runStartupSequenceIfNeeded()
            shareImportPreviewViewModel.scanInboxAndPresent()
            sharedInboxScanCoordinator.automaticScan()
        }
        .onChange(of: viewModel.screen) { newValue in
            switch newValue {
            case .setup:
                break
            case .microphoneCheck:
                sharedInboxScanCoordinator.launchTitleScreenClosed()
            case .praying:
                sharedInboxScanCoordinator.launchTitleScreenClosed()
                sharedInboxScanCoordinator.mainPrayerScreenShowing()
            }
        }
        .onOpenURL { url in
            shareImportPreviewViewModel.handleIncomingURL(url)
            sharedInboxScanCoordinator.automaticScan()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            sharedInboxScanCoordinator.automaticScan()
        }
        #endif
        .sheet(isPresented: $shareImportPreviewViewModel.isPresented) {
            ShareImportPreviewSheet(viewModel: shareImportPreviewViewModel)
        }
        .sheet(item: $shareImportPreviewViewModel.pendingImportForFinishing) { pendingImport in
            FinishImportView(
                viewModel: root.makeFinishImportViewModel(
                    pending: pendingImport,
                    onDone: {
                        shareImportPreviewViewModel.dismissPendingImportForFinishing()
                    }
                )
            )
        }
    }
}
