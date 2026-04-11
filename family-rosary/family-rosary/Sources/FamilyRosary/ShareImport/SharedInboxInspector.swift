import Foundation
import Combine

struct SharedInboxItem: Identifiable, Equatable {
    let id: String
    let importID: String
    let sourceFilename: String?
    let stagedFilename: String?
    let byteSize: Int64?
    let createdAt: Date?
    let stagedAudioPath: String?
    let receiptPath: String
    let fileExistsAtManifestPath: Bool
}

struct SharedInboxInspector {
    let paths: SharedImportPaths
    let fileManager: FileManager

    init(paths: SharedImportPaths, fileManager: FileManager = .default) {
        self.paths = paths
        self.fileManager = fileManager
    }

    func inspect() -> [SharedInboxItem] {
        guard let inboxURL = try? paths.ensureSharedInboxDirectory() else {
            return []
        }

        let folderURLs: [URL]
        do {
            folderURLs = try fileManager.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            ).filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            return []
        }

        let decoder = JSONDecoder()

        return folderURLs.map { folderURL in
            let importID = folderURL.lastPathComponent
            let receiptURL = folderURL.appendingPathComponent("receipt.json")
            let receipt: SharedRecordingReceipt?
            if let data = try? Data(contentsOf: receiptURL) {
                receipt = try? decoder.decode(SharedRecordingReceipt.self, from: data)
            } else {
                receipt = nil
            }
            let stagedAudioURL = receipt.map { folderURL.appendingPathComponent($0.stagedAudioFilename) }
            let fileExists = stagedAudioURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
            let attributes = stagedAudioURL.flatMap { try? fileManager.attributesOfItem(atPath: $0.path) }
            let byteSize = (attributes?[.size] as? NSNumber)?.int64Value
            let createdAt = attributes?[.creationDate] as? Date

            return SharedInboxItem(
                id: importID,
                importID: importID,
                sourceFilename: receipt?.sourceFilename,
                stagedFilename: receipt?.stagedAudioFilename,
                byteSize: byteSize,
                createdAt: createdAt,
                stagedAudioPath: stagedAudioURL?.path,
                receiptPath: receiptURL.path,
                fileExistsAtManifestPath: fileExists
            )
        }
    }
}

@MainActor
final class SharedInboxScanCoordinator: ObservableObject {
    @Published private(set) var items: [SharedInboxItem] = []
    @Published private(set) var logEntries: [SharedDiagnosticsEntry] = []

    private let inspector: SharedInboxInspector
    private let discoveryService: SharedRecordingDiscovering
    private let pipeline: SharedRecordingImportRunning
    private let paths: SharedImportPaths
    private let fileManager: FileManager
    private let logStore: SharedDiagnosticsLogStore
    private let logger: SharedDiagnosticsLogger

    init(
        inspector: SharedInboxInspector,
        discoveryService: SharedRecordingDiscovering,
        pipeline: SharedRecordingImportRunning,
        paths: SharedImportPaths,
        fileManager: FileManager = .default,
        logStore: SharedDiagnosticsLogStore,
        logger: SharedDiagnosticsLogger
    ) {
        self.inspector = inspector
        self.discoveryService = discoveryService
        self.pipeline = pipeline
        self.paths = paths
        self.fileManager = fileManager
        self.logStore = logStore
        self.logger = logger
    }

    func refresh() {
        items = inspector.inspect()
        logEntries = (try? logStore.loadEntries()) ?? []
    }

    func clearLogs() {
        do {
            try logStore.clear()
            DebugLog.shared.log("SHARE_INBOX logs_cleared")
        } catch {
            DebugLog.shared.log("SHARE_INBOX clear_logs_failed \(error.localizedDescription)")
        }
        refresh()
    }

    func clearSharedInbox() {
        logger.log(stage: "CLEAR_INBOX", event: "BEGIN")
        do {
            let inboxURL = try paths.ensureSharedInboxDirectory()
            let childURLs = try fileManager.contentsOfDirectory(at: inboxURL, includingPropertiesForKeys: nil)
            for child in childURLs {
                try fileManager.removeItem(at: child)
            }
            logger.log(stage: "CLEAR_INBOX", event: "SUCCESS", detail: "removed=\(childURLs.count)")
        } catch {
            logger.log(stage: "CLEAR_INBOX", event: "FAIL", detail: error.localizedDescription)
        }
        refresh()
    }

    func automaticScan() {
        let discovered = discoveryService.discover()
        logger.log(stage: "AUTO_SCAN", event: "BEGIN")
        logger.log(stage: "AUTO_SCAN", event: "FOUND", detail: "count=\(discovered.count)")
        refresh()
    }

    func scanSharedInboxNow() async {
        logger.log(stage: "SCAN_NOW", event: "BEGIN")
        let discovered = discoveryService.discover()

        guard discovered.isEmpty == false else {
            logger.log(stage: "SCAN_NOW", event: "ZERO_ITEMS")
            refresh()
            return
        }

        logger.log(stage: "SCAN_NOW", event: "FOUND", detail: "count=\(discovered.count)")
        let results = await pipeline.processAllPending()
        for result in results.sorted(by: { $0.importID < $1.importID }) {
            switch result.status {
            case .imported(let imported):
                logger.log(stage: "APP_IMPORT", event: "SUCCESS", detail: "importID=\(result.importID) file=\(imported.filename)")
            case .failed(let message):
                logger.log(stage: "APP_IMPORT", event: "FAIL", detail: "importID=\(result.importID) reason=\(message)")
            }
        }
        refresh()
    }
}
