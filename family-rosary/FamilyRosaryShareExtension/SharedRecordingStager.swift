import Foundation
import UniformTypeIdentifiers

private enum SharedContainerLayout {
    static let diagnosticsDirectoryName = "SharedDiagnostics"
    static let logFilename = "entries.jsonl"
    static let inboxDirectoryName = "SharedInbox"
}

struct ShareImportLogger {
    let sessionID: String
    let appGroupIdentifier: String
    let fileManager: FileManager

    func log(_ stage: String, details: [String: String?] = [:]) {
        let entry = SharedDiagnosticsEntry(
            timestampISO8601: Self.iso8601Formatter.string(from: Date()),
            category: "SHARE_EXT",
            stage: stage,
            event: "INFO",
            detail: formatDetails(details)
        )
        persist(entry)

        var components = ["SHARE_EXT", "session=\(sessionID)", "stage=\(stage)"]
        for key in details.keys.sorted() {
            if let value = details[key] ?? nil, value.isEmpty == false {
                components.append("\(key)=\(value)")
            }
        }
        NSLog("%@", components.joined(separator: " | "))
    }

    func fail(_ reason: String, stage: String, error: Error? = nil, details: [String: String?] = [:]) {
        var merged = details
        merged["reason"] = reason
        if let error = error as NSError? {
            merged["nsErrorDomain"] = error.domain
            merged["nsErrorCode"] = String(error.code)
        }
        let entry = SharedDiagnosticsEntry(
            timestampISO8601: Self.iso8601Formatter.string(from: Date()),
            category: "SHARE_EXT",
            stage: "FAIL \(stage)",
            event: "FAIL",
            detail: formatDetails(merged)
        )
        persist(entry)
        log("FAIL \(stage)", details: merged)
    }

    func logSharedContainerDetails() {
        log("APP_GROUP_ID", details: ["value": appGroupIdentifier])

        do {
            let store = SharedDiagnosticsLogStore(
                appGroupIdentifier: appGroupIdentifier,
                fileManager: fileManager
            )
            log("APP_GROUP_CONTAINER_URL", details: ["path": try store.containerURL().path])
            log("LOG_FILE_URL", details: ["path": try store.logFileURL().path])
            log("INBOX_URL", details: ["path": try store.inboxURL().path])
        } catch {
            fail(
                "The app group container was unavailable.",
                stage: "APP_GROUP_CONTAINER_URL",
                error: error,
                details: ["appGroupIdentifier": appGroupIdentifier]
            )
        }
    }

    func validateSharedContainerAvailability() throws {
        _ = try SharedDiagnosticsLogStore(
            appGroupIdentifier: appGroupIdentifier,
            fileManager: fileManager
        ).containerURL()
    }

    func writeExtensionCanary() {
        do {
            let store = SharedDiagnosticsLogStore(
                appGroupIdentifier: appGroupIdentifier,
                fileManager: fileManager
            )
            let inboxURL = try store.inboxURL()
            let filename = "extension-canary-\(Self.canaryTimestampFormatter.string(from: Date())).txt"
            let canaryURL = inboxURL.appendingPathComponent(filename)
            let content = "extension-canary session=\(sessionID)\n"
            guard let data = content.data(using: .utf8) else {
                throw ShareImportError.failedToPersistSharedAudioManifest(underlying: NSError(
                    domain: "FamilyRosaryShareExtension.ShareImport",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to encode extension canary text."]
                ))
            }
            try data.write(to: canaryURL, options: .atomic)
            log("EXTENSION_CANARY_WRITE_SUCCESS", details: ["path": canaryURL.path])
        } catch {
            fail("The extension canary file could not be written.", stage: "EXTENSION_CANARY_WRITE", error: error)
        }
    }

    private func persist(_ entry: SharedDiagnosticsEntry) {
        do {
            try SharedDiagnosticsLogStore(
                appGroupIdentifier: appGroupIdentifier,
                fileManager: fileManager
            ).append(entry)
        } catch {
            NSLog("SHARE_EXT | session=%@ | stage=LOG_WRITE_FAIL | reason=%@", sessionID, error.localizedDescription)
        }
    }

    private func formatDetails(_ details: [String: String?]) -> String? {
        let rendered = details.keys.sorted().compactMap { key -> String? in
            guard let value = details[key] ?? nil, value.isEmpty == false else { return nil }
            return "\(key)=\(value)"
        }
        return rendered.isEmpty ? nil : rendered.joined(separator: " | ")
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let canaryTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return formatter
    }()
}

enum ShareImportError: LocalizedError {
    case noExtensionInputItems
    case noAttachmentsOnExtensionItem
    case noAudioAttachmentProviderFound(registeredTypeIdentifiers: [String])
    case providerCouldNotLoadItem(typeIdentifier: String, underlying: Error?)
    case loadedItemWasNotFileURL
    case appGroupContainerUnavailable(appGroupIdentifier: String)
    case failedToCreateInboxDirectory(underlying: Error)
    case failedToCopySharedAudioIntoAppGroup(underlying: Error)
    case destinationFileAlreadyExists(path: String)
    case copiedFileIsEmpty
    case failedToPersistSharedAudioManifest(underlying: Error)
    case missingFileExtension

    var errorDescription: String? {
        switch self {
        case .noExtensionInputItems:
            return "Share failed: No extension input items were provided."
        case .noAttachmentsOnExtensionItem:
            return "Share failed: No attachments were found on the shared item."
        case let .noAudioAttachmentProviderFound(registeredTypeIdentifiers):
            if registeredTypeIdentifiers.isEmpty {
                return "Share failed: No audio attachment provider was found."
            }
            return "Share failed: No audio attachment provider was found. Types: \(registeredTypeIdentifiers.joined(separator: ", "))."
        case let .providerCouldNotLoadItem(typeIdentifier, underlying):
            if let underlying {
                return "Share failed: The provider could not load audio for \(typeIdentifier). \(underlying.localizedDescription)"
            }
            return "Share failed: The provider could not load audio for \(typeIdentifier)."
        case .loadedItemWasNotFileURL:
            return "Share failed: The shared item did not resolve to a file URL."
        case let .appGroupContainerUnavailable(appGroupIdentifier):
            return "Share failed: The app group container (\(appGroupIdentifier)) was unavailable."
        case .failedToCreateInboxDirectory:
            return "Share failed: The shared inbox directory could not be created."
        case .failedToCopySharedAudioIntoAppGroup:
            return "Share failed: The shared audio file could not be copied into the app group container."
        case let .destinationFileAlreadyExists(path):
            return "Share failed: The destination file already exists at \(path)."
        case .copiedFileIsEmpty:
            return "Share failed: The copied shared audio file was empty."
        case .failedToPersistSharedAudioManifest:
            return "Share failed: The shared audio manifest could not be persisted."
        case .missingFileExtension:
            return "Share failed: The shared file extension was missing and no audio type could be inferred."
        }
    }

    var asNSError: NSError {
        let nsError = self as NSError
        return NSError(domain: "FamilyRosaryShareExtension.ShareImport", code: nsError.code, userInfo: [
            NSLocalizedDescriptionKey: errorDescription ?? "Share failed."
        ])
    }
}

struct ShareAttachmentCandidate {
    let provider: NSItemProvider
    let preferredTypeIdentifier: String
    let registeredTypeIdentifiers: [String]
}

struct LoadedShareAttachment {
    let fileURL: URL
    let sourceFilename: String
    let sourceTypeIdentifier: String
    let byteCount: Int64
}

struct ShareAttachmentExtractor {
    private static let supportedTypeIdentifiers = [
        UTType.audio.identifier,
        UTType.mpeg4Audio.identifier,
        "com.apple.m4a-audio",
        UTType.mp3.identifier,
        UTType.wav.identifier
    ]

    let logger: ShareImportLogger

    func extractFirstAudioAttachment(from inputItems: [NSExtensionItem]) async throws -> LoadedShareAttachment {
        logger.log("SESSION_BEGIN")
        logger.log("INPUT_ITEMS_FOUND", details: ["count": String(inputItems.count)])

        guard inputItems.isEmpty == false else {
            logger.fail("No extension input items were provided.", stage: "INPUT_ITEMS_FOUND")
            throw ShareImportError.noExtensionInputItems
        }

        let providers = inputItems.flatMap { $0.attachments ?? [] }
        guard providers.isEmpty == false else {
            logger.fail("No attachments were found on the shared item.", stage: "AUDIO_PROVIDER_FOUND")
            throw ShareImportError.noAttachmentsOnExtensionItem
        }

        let candidate = try firstAudioCandidate(from: providers)
        logger.log(
            "AUDIO_PROVIDER_FOUND",
            details: ["registeredTypeIdentifiers": candidate.registeredTypeIdentifiers.joined(separator: ",")]
        )
        logger.log("LOAD_ITEM_BEGIN", details: ["typeIdentifier": candidate.preferredTypeIdentifier])

        let provider = candidate.provider
        let preferredTypeIdentifier = candidate.preferredTypeIdentifier
        let sessionID = logger.sessionID
        let appGroupIdentifier = logger.appGroupIdentifier

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: preferredTypeIdentifier) { sourceURL, error in
                let logger = ShareImportLogger(
                    sessionID: sessionID,
                    appGroupIdentifier: appGroupIdentifier,
                    fileManager: FileManager.default
                )
                if let error {
                    logger.fail(
                        "The provider could not load audio for \(preferredTypeIdentifier).",
                        stage: "LOAD_ITEM_BEGIN",
                        error: error
                    )
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: preferredTypeIdentifier,
                        underlying: error
                    ))
                    return
                }

                guard let sourceURL else {
                    logger.fail(
                        "The provider did not return a file URL.",
                        stage: "LOAD_ITEM_BEGIN"
                    )
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: preferredTypeIdentifier,
                        underlying: nil
                    ))
                    return
                }

                guard sourceURL.isFileURL else {
                    logger.fail("The shared item did not resolve to a file URL.", stage: "LOAD_ITEM_BEGIN")
                    continuation.resume(throwing: ShareImportError.loadedItemWasNotFileURL)
                    return
                }

                logger.log("SECURITY_SCOPE_BEGIN", details: ["path": sourceURL.path])
                let securityScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if securityScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(sourceURL.pathExtension)
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                    let byteCount = try Self.byteCount(for: tempURL, fileManager: FileManager.default)
                    logger.log(
                        "LOAD_ITEM_SUCCESS",
                        details: [
                            "sourceFilename": sourceURL.lastPathComponent,
                            "temporaryFilename": tempURL.lastPathComponent,
                            "byteCount": String(byteCount)
                        ]
                    )
                    continuation.resume(returning: LoadedShareAttachment(
                        fileURL: tempURL,
                        sourceFilename: sourceURL.lastPathComponent,
                        sourceTypeIdentifier: preferredTypeIdentifier,
                        byteCount: byteCount
                    ))
                } catch {
                    logger.fail(
                        "The provider copy into a temporary file failed.",
                        stage: "LOAD_ITEM_BEGIN",
                        error: error
                    )
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: preferredTypeIdentifier,
                        underlying: error
                    ))
                }
            }
        }
    }

    private func firstAudioCandidate(from providers: [NSItemProvider]) throws -> ShareAttachmentCandidate {
        var seenTypeIdentifiers: [String] = []

        for provider in providers {
            let registered = provider.registeredTypeIdentifiers
            seenTypeIdentifiers.append(contentsOf: registered)

            if let preferred = Self.supportedTypeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
                return ShareAttachmentCandidate(
                    provider: provider,
                    preferredTypeIdentifier: preferred,
                    registeredTypeIdentifiers: registered
                )
            }

            if let registeredAudio = registered.first(where: { identifier in
                UTType(identifier)?.conforms(to: .audio) == true
            }) {
                return ShareAttachmentCandidate(
                    provider: provider,
                    preferredTypeIdentifier: registeredAudio,
                    registeredTypeIdentifiers: registered
                )
            }
        }

        logger.fail(
            "No audio attachment provider was found.",
            stage: "AUDIO_PROVIDER_FOUND",
            details: ["registeredTypeIdentifiers": seenTypeIdentifiers.joined(separator: ",")]
        )
        throw ShareImportError.noAudioAttachmentProviderFound(registeredTypeIdentifiers: seenTypeIdentifiers)
    }

    private static func byteCount(for url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}

struct ShareImportStagingLogger: SharedAudioStagingLogging {
    let base: ShareImportLogger

    func log(_ stage: String, details: [String: String?]) {
        base.log(stage, details: details)
    }

    func fail(_ reason: String, stage: String, error: Error?, details: [String: String?]) {
        base.fail(reason, stage: stage, error: error, details: details)
    }
}

struct SharedDiagnosticsEntry: Codable {
    let timestampISO8601: String
    let category: String
    let stage: String
    let event: String
    let detail: String?
}

struct SharedDiagnosticsLogStore {
    let appGroupIdentifier: String
    let fileManager: FileManager

    func append(_ entry: SharedDiagnosticsEntry) throws {
        let fileURL = try logFileURL()
        let data = try JSONEncoder().encode(entry)

        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        let handle = try FileHandle(forWritingTo: fileURL)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: data)
        try handle.write(contentsOf: Data([0x0A]))
    }

    func containerURL() throws -> URL {
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier) else {
            throw ShareImportError.appGroupContainerUnavailable(appGroupIdentifier: appGroupIdentifier)
        }
        return containerURL
    }

    func inboxURL() throws -> URL {
        let inboxURL = try containerURL().appendingPathComponent(SharedContainerLayout.inboxDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        return inboxURL
    }

    func logFileURL() throws -> URL {
        let diagnosticsURL = try containerURL().appendingPathComponent(SharedContainerLayout.diagnosticsDirectoryName, isDirectory: true)
        try fileManager.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
        return diagnosticsURL.appendingPathComponent(SharedContainerLayout.logFilename)
    }
}
