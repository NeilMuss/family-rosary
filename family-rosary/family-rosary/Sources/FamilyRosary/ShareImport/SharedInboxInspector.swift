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

struct SharedContainerDiagnosticsSnapshot: Equatable {
    let appGroupIdentifier: String
    let containerPath: String?
    let logFilePath: String?
    let inboxPath: String?
    let containerExists: Bool
    let logFileExists: Bool
    let inboxExists: Bool
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
    @Published private(set) var sharedContainerSnapshot: SharedContainerDiagnosticsSnapshot?
    @Published private(set) var sharedContainerEntries: [String] = []

    private let inspector: SharedInboxInspector
    private let discoveryService: SharedRecordingDiscovering
    private let pipeline: SharedRecordingImportRunning
    private let paths: SharedImportPaths
    private let fileManager: FileManager
    private let logStore: SharedDiagnosticsLogStore
    private let logger: SharedDiagnosticsLogger
    private let appLogger: SharedDiagnosticsLogger
    private let debugInjector: SharedInboxDebugInjector

    init(
        inspector: SharedInboxInspector,
        discoveryService: SharedRecordingDiscovering,
        pipeline: SharedRecordingImportRunning,
        paths: SharedImportPaths,
        fileManager: FileManager = .default,
        logStore: SharedDiagnosticsLogStore,
        logger: SharedDiagnosticsLogger,
        appLogger: SharedDiagnosticsLogger,
        debugInjector: SharedInboxDebugInjector
    ) {
        self.inspector = inspector
        self.discoveryService = discoveryService
        self.pipeline = pipeline
        self.paths = paths
        self.fileManager = fileManager
        self.logStore = logStore
        self.logger = logger
        self.appLogger = appLogger
        self.debugInjector = debugInjector
    }

    func refresh() {
        items = inspector.inspect()
        logEntries = (try? logStore.loadEntries()) ?? []
        sharedContainerSnapshot = makeSharedContainerSnapshot()
        logSharedContainerDetails()
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

    func writeAppCanary() {
        logger.log(stage: "APP_CANARY", event: "BEGIN")
        do {
            let inboxURL = try paths.ensureSharedInboxDirectory()
            let canaryURL = inboxURL.appendingPathComponent("app-canary.txt")
            let content = "app-canary \(ISO8601DateFormatter().string(from: Date()))\n"
            guard let data = content.data(using: .utf8) else {
                throw NSError(domain: "SharedInboxScanCoordinator", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode app canary text."])
            }
            try data.write(to: canaryURL, options: .atomic)
            logger.log(stage: "APP_CANARY", event: "SUCCESS", detail: canaryURL.path)
        } catch {
            logger.log(stage: "APP_CANARY", event: "FAIL", detail: error.localizedDescription)
        }
        refresh()
    }

    func injectBundledTestAudio() {
        do {
            let result = try debugInjector.injectBundledTestAudio()
            logger.log(
                stage: "DEBUG_INJECT",
                event: "READY",
                detail: "importID=\(result.importID) bytes=\(result.byteCount)"
            )
        } catch {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: error.localizedDescription)
        }
        refresh()
    }

    func writeExtensionCanaryEmulation() {
        do {
            let canaryURL = try debugInjector.writeExtensionCanaryEmulation()
            logger.log(stage: "DEBUG_EXTENSION_CANARY", event: "SUCCESS", detail: canaryURL.path)
        } catch {
            logger.log(stage: "DEBUG_EXTENSION_CANARY", event: "FAIL", detail: error.localizedDescription)
        }
        refresh()
    }

    func readSharedContainer() {
        sharedContainerEntries = makeSharedContainerEntries()
        if sharedContainerEntries.isEmpty {
            logger.log(stage: "READ_SHARED_CONTAINER", event: "ZERO_ITEMS")
        } else {
            logger.log(stage: "READ_SHARED_CONTAINER", event: "FOUND", detail: "count=\(sharedContainerEntries.count)")
        }
        refresh()
    }

    func automaticScan() {
        let discovered = discoveryService.discover()
        logSharedContainerDetails()
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

    private func makeSharedContainerSnapshot() -> SharedContainerDiagnosticsSnapshot {
        let appGroupIdentifier = (try? logStore.resolvedAppGroupIdentifier()) ?? paths.appGroupIdentifier
        let containerURL = try? logStore.containerURL()
        let logFileURL = try? logStore.logFileURL()
        let inboxURL = try? paths.sharedInboxDirectoryURL()

        return SharedContainerDiagnosticsSnapshot(
            appGroupIdentifier: appGroupIdentifier,
            containerPath: containerURL?.path,
            logFilePath: logFileURL?.path,
            inboxPath: inboxURL?.path,
            containerExists: containerURL.map { fileManager.fileExists(atPath: $0.path) } ?? false,
            logFileExists: logFileURL.map { fileManager.fileExists(atPath: $0.path) } ?? false,
            inboxExists: inboxURL.map { fileManager.fileExists(atPath: $0.path) } ?? false
        )
    }

    private func makeSharedContainerEntries() -> [String] {
        guard let containerURL = try? logStore.containerURL() else {
            return []
        }

        let enumerator = fileManager.enumerator(
            at: containerURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        let entries = (enumerator?.allObjects as? [URL] ?? []).map { url in
            let relativePath = url.path.replacingOccurrences(of: "\(containerURL.path)/", with: "")
            let isDirectory = ((try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false)
            return isDirectory ? "\(relativePath)/" : relativePath
        }.sorted()

        return entries
    }

    private func logSharedContainerDetails() {
        let snapshot = makeSharedContainerSnapshot()
        appLogger.log(stage: "APP_GROUP_ID", event: "VALUE", detail: snapshot.appGroupIdentifier)
        appLogger.log(stage: "APP_GROUP_CONTAINER_URL", event: "VALUE", detail: snapshot.containerPath ?? "nil")
        appLogger.log(stage: "LOG_FILE_URL", event: "VALUE", detail: snapshot.logFilePath ?? "nil")
        appLogger.log(stage: "INBOX_URL", event: "VALUE", detail: snapshot.inboxPath ?? "nil")
    }
}
