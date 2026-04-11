import CryptoKit
import Foundation

enum SharedInboxDebugInjectorError: LocalizedError, Equatable {
    case bundledAssetMissing(name: String)
    case failedToReadBundledAsset(path: String)
    case failedToCreateStagedFolder(path: String)
    case stagedFileAlreadyExists(path: String)
    case failedToWriteStagedAudio(path: String)
    case failedToWriteReceipt(path: String)

    var errorDescription: String? {
        switch self {
        case let .bundledAssetMissing(name):
            return "Debug injection failed: bundled asset \(name) was not found."
        case let .failedToReadBundledAsset(path):
            return "Debug injection failed: bundled asset could not be read at \(path)."
        case let .failedToCreateStagedFolder(path):
            return "Debug injection failed: could not create staged folder at \(path)."
        case let .stagedFileAlreadyExists(path):
            return "Debug injection failed: staged file already exists at \(path)."
        case let .failedToWriteStagedAudio(path):
            return "Debug injection failed: could not write staged audio at \(path)."
        case let .failedToWriteReceipt(path):
            return "Debug injection failed: could not write receipt at \(path)."
        }
    }
}

struct SharedInboxDebugInjectionResult: Equatable {
    let importID: String
    let stagedAudioURL: URL
    let receiptURL: URL
    let byteCount: Int64
}

struct SharedInboxDebugInjector {
    static let bundledAssetName = "debug_share_seed"
    static let bundledAssetExtension = "m4a"

    let paths: SharedImportPaths
    let fileManager: FileManager
    let logger: SharedDiagnosticsLogger
    let bundle: Bundle
    let bundledAssetURLProvider: (() -> URL?)?
    let nowProvider: () -> Date

    init(
        paths: SharedImportPaths,
        fileManager: FileManager = .default,
        logger: SharedDiagnosticsLogger,
        bundle: Bundle = .main,
        bundledAssetURLProvider: (() -> URL?)? = nil,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.logger = logger
        self.bundle = bundle
        self.bundledAssetURLProvider = bundledAssetURLProvider
        self.nowProvider = nowProvider
    }

    func injectBundledTestAudio() throws -> SharedInboxDebugInjectionResult {
        logger.log(stage: "DEBUG_INJECT", event: "BEGIN", detail: "asset=\(Self.bundledAssetName).\(Self.bundledAssetExtension)")

        guard let sourceURL = bundledAssetURLProvider?() ?? bundle.url(
            forResource: Self.bundledAssetName,
            withExtension: Self.bundledAssetExtension
        ) else {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: SharedInboxDebugInjectorError.bundledAssetMissing(name: "\(Self.bundledAssetName).\(Self.bundledAssetExtension)").localizedDescription)
            throw SharedInboxDebugInjectorError.bundledAssetMissing(name: "\(Self.bundledAssetName).\(Self.bundledAssetExtension)")
        }

        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: sourceURL)
        } catch {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: SharedInboxDebugInjectorError.failedToReadBundledAsset(path: sourceURL.path).localizedDescription)
            throw SharedInboxDebugInjectorError.failedToReadBundledAsset(path: sourceURL.path)
        }

        let normalizedFilename = try SharedImportPaths.normalizeAudioFilename(
            originalFilename: "\(Self.bundledAssetName).\(Self.bundledAssetExtension)",
            fallbackTypeIdentifier: "public.mpeg-4-audio"
        )
        let importID = makeImportID(fileData: sourceData, normalizedFilename: normalizedFilename)
        let stagedFolderURL = try paths.stagedImportDirectoryURL(importID: importID)
        let stagedAudioURL = stagedFolderURL.appendingPathComponent(normalizedFilename)
        let receiptURL = stagedFolderURL.appendingPathComponent("receipt.json")

        do {
            try fileManager.createDirectory(at: stagedFolderURL, withIntermediateDirectories: true)
        } catch {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: SharedInboxDebugInjectorError.failedToCreateStagedFolder(path: stagedFolderURL.path).localizedDescription)
            throw SharedInboxDebugInjectorError.failedToCreateStagedFolder(path: stagedFolderURL.path)
        }

        if fileManager.fileExists(atPath: stagedAudioURL.path) || fileManager.fileExists(atPath: receiptURL.path) {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: SharedInboxDebugInjectorError.stagedFileAlreadyExists(path: stagedFolderURL.path).localizedDescription)
            throw SharedInboxDebugInjectorError.stagedFileAlreadyExists(path: stagedFolderURL.path)
        }

        do {
            try sourceData.write(to: stagedAudioURL, options: .atomic)
        } catch {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: SharedInboxDebugInjectorError.failedToWriteStagedAudio(path: stagedAudioURL.path).localizedDescription)
            throw SharedInboxDebugInjectorError.failedToWriteStagedAudio(path: stagedAudioURL.path)
        }

        let byteCount = Int64(sourceData.count)
        let receipt = SharedRecordingReceipt(
            importID: importID,
            sourceFilename: sourceURL.lastPathComponent,
            normalizedFilename: normalizedFilename,
            stagedAudioFilename: normalizedFilename,
            sourceTypeIdentifier: "public.mpeg-4-audio",
            byteCount: byteCount,
            stagedAtISO8601: SharedRecordingReceipt.iso8601Formatter.string(from: nowProvider())
        )

        do {
            let data = try JSONEncoder().encode(receipt)
            try data.write(to: receiptURL, options: .atomic)
        } catch {
            logger.log(stage: "DEBUG_INJECT", event: "FAIL", detail: SharedInboxDebugInjectorError.failedToWriteReceipt(path: receiptURL.path).localizedDescription)
            throw SharedInboxDebugInjectorError.failedToWriteReceipt(path: receiptURL.path)
        }

        logger.log(
            stage: "DEBUG_INJECT",
            event: "SUCCESS",
            detail: "importID=\(importID) bytes=\(byteCount) staged=\(stagedAudioURL.path) receipt=\(receiptURL.path)"
        )

        return SharedInboxDebugInjectionResult(
            importID: importID,
            stagedAudioURL: stagedAudioURL,
            receiptURL: receiptURL,
            byteCount: byteCount
        )
    }

    func writeExtensionCanaryEmulation() throws -> URL {
        let inboxURL = try paths.ensureSharedInboxDirectory()
        let filename = "extension-canary-emulated-\(Int(nowProvider().timeIntervalSince1970)).txt"
        let canaryURL = inboxURL.appendingPathComponent(filename)
        try Data("extension-canary-emulated\n".utf8).write(to: canaryURL, options: .atomic)
        logger.log(stage: "DEBUG_EXTENSION_CANARY", event: "SUCCESS", detail: canaryURL.path)
        return canaryURL
    }

    private func makeImportID(fileData: Data, normalizedFilename: String) -> String {
        var hashInput = Data(normalizedFilename.utf8)
        hashInput.append(fileData)
        let hash = SHA256.hash(data: hashInput)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }
}
