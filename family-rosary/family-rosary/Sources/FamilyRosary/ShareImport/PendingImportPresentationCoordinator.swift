import Foundation
import Combine

@MainActor
final class PendingImportPresentationCoordinator: ObservableObject {
    @Published private(set) var currentPendingImport: PendingImport?
    @Published private(set) var pendingQueueCount = 0
    @Published private(set) var currentQueuePosition = 0

    private let pendingStore: PendingImportStoring
    private let discoveryService: SharedRecordingDiscovering
    private let pipeline: SharedRecordingImportRunning
    private let deepLinkHandler: ShareImportDeepLinkHandler
    private let logger: SharedDiagnosticsLogger

    init(
        pendingStore: PendingImportStoring,
        discoveryService: SharedRecordingDiscovering,
        pipeline: SharedRecordingImportRunning,
        deepLinkHandler: ShareImportDeepLinkHandler,
        logger: SharedDiagnosticsLogger
    ) {
        self.pendingStore = pendingStore
        self.discoveryService = discoveryService
        self.pipeline = pipeline
        self.deepLinkHandler = deepLinkHandler
        self.logger = logger
    }

    func refreshPendingQueue() {
        let previousPendingID = currentPendingImport?.id
        let pendingImports = loadSortedPendingImports()

        pendingQueueCount = pendingImports.count
        logger.log(stage: "PENDING_IMPORT_QUEUE_COUNT", event: "INFO", detail: "count=\(pendingImports.count)")

        guard pendingImports.isEmpty == false else {
            currentPendingImport = nil
            currentQueuePosition = 0
            return
        }

        if let previousPendingID,
           let existingIndex = pendingImports.firstIndex(where: { $0.id == previousPendingID }) {
            currentPendingImport = pendingImports[existingIndex]
            currentQueuePosition = existingIndex + 1
            return
        }

        currentPendingImport = pendingImports[0]
        currentQueuePosition = 1

        if previousPendingID == nil {
            logger.log(
                stage: "FINISH_IMPORT_PRESENTED",
                event: "INFO",
                detail: "importID=\(pendingImports[0].importID) position=1 total=\(pendingImports.count)"
            )
        } else {
            logger.log(
                stage: "NEXT_PENDING_IMPORT_PRESENTED",
                event: "INFO",
                detail: "importID=\(pendingImports[0].importID) position=1 total=\(pendingImports.count)"
            )
        }
    }

    func handleIncomingURL(_ url: URL) {
        guard deepLinkHandler.recognizes(url) else {
            return
        }

        Task { @MainActor in
            await importPendingSharedItems()
            refreshPendingQueue()
        }
    }

    func finishImportCompleted() {
        refreshPendingQueue()
    }

    private func importPendingSharedItems() async {
        logger.log(stage: "SCAN_BEGIN", event: "INFO")
        let discoveredItems = discoveryService.discover().sorted { $0.importID < $1.importID }
        guard discoveredItems.isEmpty == false else {
            logger.log(stage: "SCAN_COMPLETE", event: "ZERO_ITEMS")
            return
        }

        for item in discoveredItems {
            logger.log(stage: "ITEM_FOUND", event: "INFO", detail: "importID=\(item.importID)")
        }

        let results = await pipeline.processAllPending()
        for result in results.sorted(by: { $0.importID < $1.importID }) {
            switch result.status {
            case .pendingMetadata(let pendingImport):
                logger.log(
                    stage: "PENDING_IMPORT_CREATED",
                    event: "INFO",
                    detail: "importID=\(pendingImport.importID) file=\(pendingImport.originalFilename)"
                )
            case .failed(let message):
                logger.log(
                    stage: "SCAN_FAIL",
                    event: "FAIL",
                    detail: "importID=\(result.importID) reason=\(message)"
                )
            }
        }
    }

    private func loadSortedPendingImports() -> [PendingImport] {
        let pendingImports = (try? pendingStore.all()) ?? []
        return pendingImports.sorted { lhs, rhs in
            if lhs.importedAtISO8601 != rhs.importedAtISO8601 {
                return lhs.importedAtISO8601 < rhs.importedAtISO8601
            }
            return lhs.id < rhs.id
        }
    }
}
