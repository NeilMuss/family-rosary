import Foundation

struct SharedRecordingImportResult: Equatable {
    enum Status: Equatable {
        case imported(ImportedRecording)
        case failed(message: String)
    }

    let importID: String
    let status: Status
}

protocol SharedRecordingImportRunning {
    func processAllPending() async -> [SharedRecordingImportResult]
    func process(importID: String) async -> SharedRecordingImportResult
}

struct SharedRecordingImportPipeline: SharedRecordingImportRunning {
    let paths: SharedImportPaths
    let discoveryService: SharedRecordingDiscovering
    let audioInspector: SharedAudioInspecting
    let audioPreparationService: ImportedAudioPreparing
    let recordingStore: ImportedRecordingStoring
    let fileManager: FileManager
    let logger: SharedImportDiagnosticsLogger
    let sessionIDProvider: () -> String
    let nowProvider: () -> Date
    let baseDirURLProvider: () -> URL

    init(
        paths: SharedImportPaths,
        discoveryService: SharedRecordingDiscovering,
        audioInspector: SharedAudioInspecting,
        audioPreparationService: ImportedAudioPreparing,
        recordingStore: ImportedRecordingStoring,
        fileManager: FileManager = .default,
        logger: SharedImportDiagnosticsLogger = SharedImportDiagnosticsLogger(),
        sessionIDProvider: @escaping () -> String = { UUID().uuidString },
        nowProvider: @escaping () -> Date = Date.init,
        baseDirURLProvider: @escaping () -> URL = { FamilyRosaryPaths.baseDirURL() }
    ) {
        self.paths = paths
        self.discoveryService = discoveryService
        self.audioInspector = audioInspector
        self.audioPreparationService = audioPreparationService
        self.recordingStore = recordingStore
        self.fileManager = fileManager
        self.logger = logger
        self.sessionIDProvider = sessionIDProvider
        self.nowProvider = nowProvider
        self.baseDirURLProvider = baseDirURLProvider
    }

    func processAllPending() async -> [SharedRecordingImportResult] {
        let items = discoveryService.discover().sorted { $0.importID < $1.importID }
        var results: [SharedRecordingImportResult] = []
        for item in items {
            results.append(await process(importID: item.importID))
        }
        return results
    }

    func process(importID: String) async -> SharedRecordingImportResult {
        let sessionID = sessionIDProvider()
        logger.log(sessionID: sessionID, importID: importID, stage: "SESSION", event: .info, reason: "started")

        do {
            let stagedFolderURL = try paths.stagedImportDirectoryURL(importID: importID)
            guard fileManager.fileExists(atPath: stagedFolderURL.path) else {
                throw SharedRecordingImportError.stagedImportFolderMissing(importID: importID)
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "VALIDATE_FOLDER", event: .pass, path: stagedFolderURL.path)

            let receiptURL = stagedFolderURL.appendingPathComponent("receipt.json")
            guard fileManager.fileExists(atPath: receiptURL.path) else {
                throw SharedRecordingImportError.stagedReceiptMissing(importID: importID)
            }

            let receiptData: Data
            let receipt: SharedRecordingReceipt
            do {
                receiptData = try Data(contentsOf: receiptURL)
                receipt = try JSONDecoder().decode(SharedRecordingReceipt.self, from: receiptData)
            } catch {
                throw SharedRecordingImportError.stagedReceiptUnreadable(importID: importID)
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "VALIDATE_RECEIPT", event: .pass, path: receiptURL.path)

            let stagedAudioURL = stagedFolderURL.appendingPathComponent(receipt.stagedAudioFilename)
            guard fileManager.fileExists(atPath: stagedAudioURL.path) else {
                throw SharedRecordingImportError.sharedAudioMissing(importID: importID, expectedFilename: receipt.stagedAudioFilename)
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "VALIDATE_AUDIO_FILE", event: .pass, path: stagedAudioURL.path)

            let attributes = try fileManager.attributesOfItem(atPath: stagedAudioURL.path)
            let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard fileSize > 0 else {
                throw SharedRecordingImportError.sharedAudioEmpty(importID: importID)
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "VALIDATE_FILE_SIZE", event: .pass, path: stagedAudioURL.path, reason: "bytes=\(fileSize)")

            guard fileManager.isReadableFile(atPath: stagedAudioURL.path) else {
                throw SharedRecordingImportError.sharedAudioUnreadable(importID: importID)
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "VALIDATE_READABLE", event: .pass, path: stagedAudioURL.path)

            let inspection: SharedAudioInspection
            do {
                inspection = try audioInspector.inspect(url: stagedAudioURL)
            } catch {
                throw SharedRecordingImportError.sharedAudioUndecodable(importID: importID)
            }
            logger.log(
                sessionID: sessionID,
                importID: importID,
                stage: "VALIDATE_DURATION",
                event: .pass,
                path: stagedAudioURL.path,
                reason: String(format: "seconds=%.2f", inspection.durationSeconds)
            )

            let libraryDirURL = try FamilyRosaryPaths.importedSharedAudioDirURL(baseDirURL: baseDirURLProvider())
            let normalizedStem = URL(fileURLWithPath: receipt.normalizedFilename).deletingPathExtension().lastPathComponent
            let destinationFilename = "shared_\(importID)_\(normalizedStem).\(CanonicalAudioFormat.speech.fileExtension)"
            let destinationURL = libraryDirURL.appendingPathComponent(destinationFilename)

            do {
                let preparedAudio = try await audioPreparationService.prepare(
                    sourceURL: stagedAudioURL,
                    destinationURL: destinationURL
                )
                logger.log(
                    sessionID: sessionID,
                    importID: importID,
                    stage: "CANONICALIZE_AUDIO",
                    event: .pass,
                    path: preparedAudio.fileURL.path,
                    reason: "strategy=\(preparedAudio.strategy) bytes=\(preparedAudio.inspection.fileSizeBytes)"
                )
            } catch {
                throw SharedRecordingImportError.canonicalizationFailed(
                    importID: importID,
                    reason: error.localizedDescription
                )
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "COPY_TO_LIBRARY", event: .pass, path: destinationURL.path)

            let importedAt = nowProvider()
            let importedRecording = ImportedRecording(
                id: "\(importID)-\(Int(importedAt.timeIntervalSince1970))",
                importID: importID,
                filename: destinationFilename,
                libraryRelativePath: "imported_shared_audio/\(destinationFilename)",
                durationSeconds: inspection.durationSeconds,
                importedAtISO8601: SharedRecordingReceipt.iso8601Formatter.string(from: importedAt)
            )

            do {
                try recordingStore.register(importedRecording)
            } catch {
                throw SharedRecordingImportError.appLibraryRegisterFailed(importID: importID, underlying: error)
            }
            logger.log(sessionID: sessionID, importID: importID, stage: "REGISTER_RECORDING", event: .pass)

            do {
                try fileManager.removeItem(at: stagedFolderURL)
                logger.log(sessionID: sessionID, importID: importID, stage: "CLEANUP", event: .pass, path: stagedFolderURL.path)
            } catch {
                logger.log(
                    sessionID: sessionID,
                    importID: importID,
                    stage: "CLEANUP",
                    event: .fail,
                    path: stagedFolderURL.path,
                    reason: error.localizedDescription
                )
            }

            logger.log(sessionID: sessionID, importID: importID, stage: "SESSION", event: .pass, reason: "completed")
            return SharedRecordingImportResult(importID: importID, status: .imported(importedRecording))
        } catch {
            logger.log(
                sessionID: sessionID,
                importID: importID,
                stage: "SESSION",
                event: .fail,
                reason: error.localizedDescription
            )
            return SharedRecordingImportResult(importID: importID, status: .failed(message: error.localizedDescription))
        }
    }
}
