import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AppRootView: View {
    private let root: AppCompositionRoot
    @StateObject private var viewModel: FamilyRosaryFlowViewModel
    @StateObject private var pendingImportCoordinator: PendingImportPresentationCoordinator
    @StateObject private var sharedInboxScanCoordinator: SharedInboxScanCoordinator

    init(root: AppCompositionRoot) {
        self.root = root
        _viewModel = StateObject(wrappedValue: root.makeFamilyRosaryFlowViewModel())
        _pendingImportCoordinator = StateObject(wrappedValue: root.makePendingImportPresentationCoordinator())
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
            await pendingImportCoordinator.importPendingSharedItemsAndRefreshPresentation()
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
            pendingImportCoordinator.handleIncomingURL(url)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sharedPendingImportsDidChange)) { _ in
            pendingImportCoordinator.refreshPendingQueue()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            Task { @MainActor in
                await pendingImportCoordinator.importPendingSharedItemsAndRefreshPresentation()
            }
        }
        #endif
        .sheet(
            item: Binding(
                get: { pendingImportCoordinator.currentPendingImport },
                set: { _ in }
            )
        ) { pendingImport in
            FinishImportView(
                viewModel: root.makeFinishImportViewModel(
                    pending: pendingImport,
                    queuePosition: pendingImportCoordinator.currentQueuePosition,
                    totalPendingCount: pendingImportCoordinator.pendingQueueCount,
                    onDone: {
                        pendingImportCoordinator.finishImportCompleted()
                    }
                )
            )
        }
    }
}
