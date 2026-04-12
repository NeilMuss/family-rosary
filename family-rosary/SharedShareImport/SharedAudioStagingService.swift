import CryptoKit
import Foundation
import UniformTypeIdentifiers

protocol SharedAudioStaging {
    func stage(_ request: SharedAudioStagingRequest) throws -> SharedAudioStagingResult
}

protocol SharedAudioStagingLogging {
    func log(_ stage: String, details: [String: String?])
    func fail(_ reason: String, stage: String, error: Error?, details: [String: String?])
}

struct SharedAudioStagingRequest: Equatable {
    let sourceFileURL: URL
    let sourceFilename: String
    let sourceTypeIdentifier: String?
    let byteCount: Int64?
}

struct SharedAudioStagingReceipt: Codable, Equatable {
    let importID: String
    let sourceFilename: String
    let normalizedFilename: String
    let stagedAudioFilename: String
    let sourceTypeIdentifier: String?
    let byteCount: Int64
    let stagedAtISO8601: String
}

struct SharedAudioStagingResult: Equatable {
    let importID: String
    let stagedFolderURL: URL
    let receiptURL: URL
    let stagedAudioURL: URL
    let receipt: SharedAudioStagingReceipt
}

enum SharedAudioStagingError: LocalizedError, Equatable {
    case appGroupIdentifierMissing
    case appGroupContainerUnavailable(appGroupIdentifier: String)
    case failedToCreateInboxDirectory(path: String)
    case destinationFileAlreadyExists(path: String)
    case failedToCopySharedAudioIntoAppGroup(path: String)
    case copiedFileIsEmpty(path: String)
    case failedToPersistSharedAudioManifest(path: String)
    case missingFileExtension

    var errorDescription: String? {
        switch self {
        case .appGroupIdentifierMissing:
            return "Share failed: The app group identifier is missing."
        case let .appGroupContainerUnavailable(appGroupIdentifier):
            return "Share failed: The app group container (\(appGroupIdentifier)) was unavailable."
        case .failedToCreateInboxDirectory:
            return "Share failed: The shared inbox directory could not be created."
        case let .destinationFileAlreadyExists(path):
            return "Share failed: The destination file already exists at \(path)."
        case .failedToCopySharedAudioIntoAppGroup:
            return "Share failed: The shared audio file could not be copied into the app group container."
        case .copiedFileIsEmpty:
            return "Share failed: The copied shared audio file was empty."
        case .failedToPersistSharedAudioManifest:
            return "Share failed: The shared audio manifest could not be persisted."
        case .missingFileExtension:
            return "Share failed: The shared file extension was missing and no audio type could be inferred."
        }
    }
}

struct SharedAudioStagingService: SharedAudioStaging {
    let appGroupIdentifier: String
    let fileManager: FileManager
    let nowProvider: () -> Date
    let logger: any SharedAudioStagingLogging
    let sharedContainerURLProvider: (() -> URL?)?

    init(
        appGroupIdentifier: String,
        fileManager: FileManager = .default,
        nowProvider: @escaping () -> Date = Date.init,
        logger: any SharedAudioStagingLogging,
        sharedContainerURLProvider: (() -> URL?)? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
        self.nowProvider = nowProvider
        self.logger = logger
        self.sharedContainerURLProvider = sharedContainerURLProvider
    }

    func stage(_ request: SharedAudioStagingRequest) throws -> SharedAudioStagingResult {
        let byteCount = request.byteCount ?? (try? Self.byteCount(for: request.sourceFileURL, fileManager: fileManager)) ?? 0
        logger.log("COPY_BEGIN", details: [
            "sourceFilename": request.sourceFilename,
            "sourceTypeIdentifier": request.sourceTypeIdentifier,
            "byteCount": String(byteCount)
        ])

        let trimmedIdentifier = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            logger.fail("The app group identifier is missing.", stage: "COPY_BEGIN", error: nil, details: [:])
            throw SharedAudioStagingError.appGroupIdentifierMissing
        }

        let containerURL = sharedContainerURLProvider?() ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: trimmedIdentifier)
        guard let containerURL else {
            logger.fail(
                "The app group container was unavailable.",
                stage: "COPY_BEGIN",
                error: nil,
                details: ["appGroupIdentifier": trimmedIdentifier]
            )
            throw SharedAudioStagingError.appGroupContainerUnavailable(appGroupIdentifier: trimmedIdentifier)
        }

        let inboxURL = containerURL.appendingPathComponent("SharedInbox", isDirectory: true)
        do {
            try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        } catch {
            logger.fail("The shared inbox directory could not be created.", stage: "COPY_BEGIN", error: error, details: ["path": inboxURL.path])
            throw SharedAudioStagingError.failedToCreateInboxDirectory(path: inboxURL.path)
        }

        let normalizedFilename = try normalizeAudioFilename(
            originalFilename: request.sourceFilename,
            fallbackTypeIdentifier: request.sourceTypeIdentifier
        )
        let fileData = try Data(contentsOf: request.sourceFileURL)
        let importID = makeImportID(fileData: fileData, normalizedFilename: normalizedFilename)
        let stagedFolderURL = inboxURL.appendingPathComponent(importID, isDirectory: true)
        let stagedAudioURL = stagedFolderURL.appendingPathComponent(normalizedFilename)
        let receiptURL = stagedFolderURL.appendingPathComponent("receipt.json")

        do {
            try fileManager.createDirectory(at: stagedFolderURL, withIntermediateDirectories: true)
        } catch {
            logger.fail("The shared inbox directory could not be created.", stage: "COPY_BEGIN", error: error, details: ["path": stagedFolderURL.path])
            throw SharedAudioStagingError.failedToCreateInboxDirectory(path: stagedFolderURL.path)
        }

        if fileManager.fileExists(atPath: stagedAudioURL.path) || fileManager.fileExists(atPath: receiptURL.path) {
            logger.fail("The destination file already exists.", stage: "COPY_BEGIN", error: nil, details: ["path": stagedFolderURL.path])
            throw SharedAudioStagingError.destinationFileAlreadyExists(path: stagedFolderURL.path)
        }

        do {
            try fileManager.copyItem(at: request.sourceFileURL, to: stagedAudioURL)
        } catch {
            logger.fail(
                "The shared audio file could not be copied into the app group container.",
                stage: "COPY_BEGIN",
                error: error,
                details: ["path": stagedAudioURL.path]
            )
            throw SharedAudioStagingError.failedToCopySharedAudioIntoAppGroup(path: stagedAudioURL.path)
        }

        let copiedByteCount = try Self.byteCount(for: stagedAudioURL, fileManager: fileManager)
        guard copiedByteCount > 0 else {
            logger.fail("The copied shared audio file was empty.", stage: "COPY_BEGIN", error: nil, details: ["path": stagedAudioURL.path])
            throw SharedAudioStagingError.copiedFileIsEmpty(path: stagedAudioURL.path)
        }

        logger.log("COPY_SUCCESS", details: [
            "destinationFilename": stagedAudioURL.lastPathComponent,
            "destinationPath": stagedAudioURL.path,
            "byteCount": String(copiedByteCount)
        ])

        let receipt = SharedAudioStagingReceipt(
            importID: importID,
            sourceFilename: request.sourceFilename,
            normalizedFilename: normalizedFilename,
            stagedAudioFilename: normalizedFilename,
            sourceTypeIdentifier: request.sourceTypeIdentifier,
            byteCount: copiedByteCount,
            stagedAtISO8601: Self.iso8601Formatter.string(from: nowProvider())
        )

        logger.log("MANIFEST_WRITE_BEGIN", details: [
            "importID": importID,
            "receiptPath": receiptURL.path
        ])

        do {
            let receiptData = try JSONEncoder().encode(receipt)
            try receiptData.write(to: receiptURL, options: .atomic)
        } catch {
            logger.fail("The shared audio manifest could not be persisted.", stage: "MANIFEST_WRITE_SUCCESS", error: error, details: ["path": receiptURL.path])
            throw SharedAudioStagingError.failedToPersistSharedAudioManifest(path: receiptURL.path)
        }

        logger.log("MANIFEST_WRITE_SUCCESS", details: [
            "importID": importID,
            "receiptFilename": receiptURL.lastPathComponent
        ])

        return SharedAudioStagingResult(
            importID: importID,
            stagedFolderURL: stagedFolderURL,
            receiptURL: receiptURL,
            stagedAudioURL: stagedAudioURL,
            receipt: receipt
        )
    }

    private func makeImportID(fileData: Data, normalizedFilename: String) -> String {
        var hashInput = Data(normalizedFilename.utf8)
        hashInput.append(fileData)
        let hash = SHA256.hash(data: hashInput)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func normalizeAudioFilename(originalFilename: String, fallbackTypeIdentifier: String?) throws -> String {
        let parsed = NSString(string: originalFilename)
        let sourceName = parsed.deletingPathExtension
        let sourceExtension = parsed.pathExtension

        let stem = sourceName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()

        let finalStem = stem.isEmpty ? "shared_audio" : stem
        let normalizedSourceExtension = sourceExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSourceExtension.isEmpty {
            return "\(finalStem).\(normalizedSourceExtension)"
        }

        if let fallbackTypeIdentifier,
           let type = UTType(fallbackTypeIdentifier),
           let inferred = type.preferredFilenameExtension,
           !inferred.isEmpty {
            return "\(finalStem).\(inferred.lowercased())"
        }

        logger.fail("The shared file extension was missing and no audio type could be inferred.", stage: "COPY_BEGIN", error: nil, details: [:])
        throw SharedAudioStagingError.missingFileExtension
    }

    private static func byteCount(for url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
