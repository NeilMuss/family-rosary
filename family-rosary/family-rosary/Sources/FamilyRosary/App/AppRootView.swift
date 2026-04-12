import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppRootView: View {
    @StateObject private var viewModel: FamilyRosaryFlowViewModel
    @StateObject private var shareImportPreviewViewModel: ShareImportPreviewViewModel
    @StateObject private var sharedInboxScanCoordinator: SharedInboxScanCoordinator

    init(root: AppCompositionRoot) {
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
            sharedInboxScanCoordinator.appSessionBegin()
            shareImportPreviewViewModel.scanInboxAndPresent()
            sharedInboxScanCoordinator.automaticScan()
        }
        .onOpenURL { url in
            shareImportPreviewViewModel.handleIncomingURL(url)
            sharedInboxScanCoordinator.automaticScan()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            sharedInboxScanCoordinator.appBecameActive()
            sharedInboxScanCoordinator.automaticScan()
        }
        #endif
        .sheet(isPresented: $shareImportPreviewViewModel.isPresented) {
            ShareImportPreviewSheet(viewModel: shareImportPreviewViewModel)
        }
    }
}
