import Foundation

struct SharedRecordingDiscoveredItem: Equatable, Identifiable {
    enum Status: Equatable {
        case ready
        case malformed(reason: String)
    }

    let id: String
    let importID: String
    let folderURL: URL
    let receiptURL: URL
    let receipt: SharedRecordingReceipt?
    let audioFileURL: URL?
    let status: Status
}

protocol SharedRecordingDiscovering {
    func discover() -> [SharedRecordingDiscoveredItem]
}

struct SharedRecordingDiscoveryService: SharedRecordingDiscovering {
    let paths: SharedImportPaths
    let fileManager: FileManager
    let logger: SharedImportDiagnosticsLogger
    let sessionIDProvider: () -> String

    init(
        paths: SharedImportPaths,
        fileManager: FileManager = .default,
        logger: SharedImportDiagnosticsLogger = SharedImportDiagnosticsLogger(),
        sessionIDProvider: @escaping () -> String = { UUID().uuidString }
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.logger = logger
        self.sessionIDProvider = sessionIDProvider
    }

    func discover() -> [SharedRecordingDiscoveredItem] {
        let sessionID = sessionIDProvider()
        logger.log(sessionID: sessionID, importID: nil, stage: "DISCOVER", event: .info)

        guard let inboxURL = try? paths.ensureSharedInboxDirectory() else {
            logger.log(
                sessionID: sessionID,
                importID: nil,
                stage: "DISCOVER",
                event: .fail,
                reason: "Failed to access shared inbox directory."
            )
            return []
        }

        let subfolderURLs: [URL]
        do {
            subfolderURLs = try fileManager.contentsOfDirectory(
                at: inboxURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles]
            )
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            logger.log(
                sessionID: sessionID,
                importID: nil,
                stage: "DISCOVER",
                event: .fail,
                path: inboxURL.path,
                reason: "Failed to enumerate shared inbox: \(error.localizedDescription)"
            )
            return []
        }

        let decoder = JSONDecoder()

        return subfolderURLs.map { folderURL in
            let importID = folderURL.lastPathComponent
            let receiptURL = folderURL.appendingPathComponent("receipt.json")
            guard fileManager.fileExists(atPath: receiptURL.path) else {
                logger.log(
                    sessionID: sessionID,
                    importID: importID,
                    stage: "VALIDATE_RECEIPT",
                    event: .fail,
                    path: receiptURL.path,
                    reason: "The staged shared import receipt is missing."
                )
                return SharedRecordingDiscoveredItem(
                    id: importID,
                    importID: importID,
                    folderURL: folderURL,
                    receiptURL: receiptURL,
                    receipt: nil,
                    audioFileURL: nil,
                    status: .malformed(reason: "The staged shared import receipt is missing.")
                )
            }

            guard let receiptData = try? Data(contentsOf: receiptURL),
                  let receipt = try? decoder.decode(SharedRecordingReceipt.self, from: receiptData) else {
                logger.log(
                    sessionID: sessionID,
                    importID: importID,
                    stage: "VALIDATE_RECEIPT",
                    event: .fail,
                    path: receiptURL.path,
                    reason: "The staged shared import receipt could not be decoded."
                )
                return SharedRecordingDiscoveredItem(
                    id: importID,
                    importID: importID,
                    folderURL: folderURL,
                    receiptURL: receiptURL,
                    receipt: nil,
                    audioFileURL: nil,
                    status: .malformed(reason: "The staged shared import receipt could not be decoded.")
                )
            }

            let audioURL = folderURL.appendingPathComponent(receipt.stagedAudioFilename)
            if fileManager.fileExists(atPath: audioURL.path) == false {
                logger.log(
                    sessionID: sessionID,
                    importID: importID,
                    stage: "VALIDATE_AUDIO_FILE",
                    event: .fail,
                    path: audioURL.path,
                    reason: "The staged shared audio file could not be found."
                )
                return SharedRecordingDiscoveredItem(
                    id: importID,
                    importID: importID,
                    folderURL: folderURL,
                    receiptURL: receiptURL,
                    receipt: receipt,
                    audioFileURL: nil,
                    status: .malformed(reason: "The staged shared audio file could not be found.")
                )
            }

            return SharedRecordingDiscoveredItem(
                id: importID,
                importID: importID,
                folderURL: folderURL,
                receiptURL: receiptURL,
                receipt: receipt,
                audioFileURL: audioURL,
                status: .ready
            )
        }
    }
}
