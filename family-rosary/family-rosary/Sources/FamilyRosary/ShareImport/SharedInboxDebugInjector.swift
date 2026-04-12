import Foundation

enum SharedInboxDebugInjectorError: LocalizedError, Equatable {
    case bundledAssetMissing(name: String)
    case failedToReadBundledAsset(path: String)

    var errorDescription: String? {
        switch self {
        case let .bundledAssetMissing(name):
            return "Debug injection failed: bundled asset \(name) was not found."
        case let .failedToReadBundledAsset(path):
            return "Debug injection failed: bundled asset could not be read at \(path)."
        }
    }
}

typealias SharedInboxDebugInjectionResult = SharedAudioStagingResult

struct SharedInboxDebugInjector {
    static let bundledAssetName = "debug_share_seed"
    static let bundledAssetExtension = "m4a"

    let paths: SharedImportPaths
    let fileManager: FileManager
    let logger: SharedDiagnosticsLogger
    let bundle: Bundle
    let bundledAssetURLProvider: (() -> URL?)?
    let nowProvider: () -> Date
    let stagingService: (any SharedAudioStaging)?

    init(
        paths: SharedImportPaths,
        fileManager: FileManager = .default,
        logger: SharedDiagnosticsLogger,
        bundle: Bundle = .main,
        bundledAssetURLProvider: (() -> URL?)? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        stagingService: (any SharedAudioStaging)? = nil
    ) {
        self.paths = paths
        self.fileManager = fileManager
        self.logger = logger
        self.bundle = bundle
        self.bundledAssetURLProvider = bundledAssetURLProvider
        self.nowProvider = nowProvider
        self.stagingService = stagingService
    }

    func injectBundledTestAudio() throws -> SharedInboxDebugInjectionResult {
        guard let sourceURL = bundledAssetURLProvider?() ?? bundle.url(
            forResource: Self.bundledAssetName,
            withExtension: Self.bundledAssetExtension
        ) else {
            throw SharedInboxDebugInjectorError.bundledAssetMissing(name: "\(Self.bundledAssetName).\(Self.bundledAssetExtension)")
        }

        let sourceData: Data
        do {
            sourceData = try Data(contentsOf: sourceURL)
        } catch {
            throw SharedInboxDebugInjectorError.failedToReadBundledAsset(path: sourceURL.path)
        }
        logger.log(
            stage: "SOURCE_FOUND",
            event: "INFO",
            detail: "sourceFilename=\(sourceURL.lastPathComponent) path=\(sourceURL.path) bytes=\(sourceData.count)"
        )
        let resolvedContainerURL = try paths.sharedContainerURL()
        let stagingService = stagingService ?? SharedAudioStagingService(
            appGroupIdentifier: paths.appGroupIdentifier,
            fileManager: fileManager,
            nowProvider: nowProvider,
            logger: SharedDiagnosticsStagingLogger(base: logger),
            sharedContainerURLProvider: { resolvedContainerURL }
        )
        let result = try stagingService.stage(
            SharedAudioStagingRequest(
                sourceFileURL: sourceURL,
                sourceFilename: sourceURL.lastPathComponent,
                sourceTypeIdentifier: "public.mpeg-4-audio",
                byteCount: Int64(sourceData.count)
            )
        )

        guard fileManager.fileExists(atPath: result.stagedAudioURL.path) else {
            throw SharedAudioStagingError.failedToCopySharedAudioIntoAppGroup(path: result.stagedAudioURL.path)
        }
        logger.log(
            stage: "DESTINATION_EXISTS_CONFIRMED",
            event: "INFO",
            detail: "importID=\(result.importID) destinationPath=\(result.stagedAudioURL.path)"
        )
        return result
    }

    func writeExtensionCanaryEmulation() throws -> URL {
        let inboxURL = try paths.ensureSharedInboxDirectory()
        let filename = "extension-canary-emulated-\(Int(nowProvider().timeIntervalSince1970)).txt"
        let canaryURL = inboxURL.appendingPathComponent(filename)
        try Data("extension-canary-emulated\n".utf8).write(to: canaryURL, options: .atomic)
        logger.log(stage: "DEBUG_EXTENSION_CANARY", event: "SUCCESS", detail: canaryURL.path)
        return canaryURL
    }
}

private struct SharedDiagnosticsStagingLogger: SharedAudioStagingLogging {
    let base: SharedDiagnosticsLogger

    func log(_ stage: String, details: [String: String?]) {
        base.log(stage: stage, event: "INFO", detail: format(details))
    }

    func fail(_ reason: String, stage: String, error: Error?, details: [String: String?]) {
        var merged = details
        merged["reason"] = reason
        if let error {
            merged["error"] = error.localizedDescription
        }
        base.log(stage: stage, event: "FAIL", detail: format(merged))
    }

    private func format(_ details: [String: String?]) -> String? {
        let rendered = details.keys.sorted().compactMap { key -> String? in
            guard let value = details[key] ?? nil, !value.isEmpty else { return nil }
            return "\(key)=\(value)"
        }
        return rendered.isEmpty ? nil : rendered.joined(separator: " ")
    }
}
