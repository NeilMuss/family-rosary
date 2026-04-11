import CryptoKit
import Foundation
import UniformTypeIdentifiers

struct ShareImportLogger {
    let sessionID: String

    func log(_ stage: String, details: [String: String?] = [:]) {
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
        log("FAIL \(stage)", details: merged)
    }
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

struct ShareAttachmentCandidate: @unchecked Sendable {
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

struct SharedAudioInboxRecord: Codable, Equatable {
    let importID: String
    let sourceFilename: String
    let normalizedFilename: String
    let stagedAudioFilename: String
    let sourceTypeIdentifier: String?
    let byteCount: Int64
    let stagedAtISO8601: String
}

struct SharedAudioInboxWriteResult {
    let importID: String
    let stagedFolderURL: URL
    let receiptURL: URL
    let stagedAudioURL: URL
    let record: SharedAudioInboxRecord
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
            logger.fail("No attachments were found on the shared item.", stage: "ATTACHMENT_PROVIDER_FOUND")
            throw ShareImportError.noAttachmentsOnExtensionItem
        }

        let candidate = try firstAudioCandidate(from: providers)
        logger.log(
            "ATTACHMENT_PROVIDER_FOUND",
            details: ["registeredTypeIdentifiers": candidate.registeredTypeIdentifiers.joined(separator: ",")]
        )
        logger.log("PROVIDER_TYPE_CONFIRMED", details: ["typeIdentifier": candidate.preferredTypeIdentifier])
        logger.log("LOAD_ITEM_BEGIN", details: ["typeIdentifier": candidate.preferredTypeIdentifier])

        return try await withCheckedThrowingContinuation { continuation in
            candidate.provider.loadFileRepresentation(forTypeIdentifier: candidate.preferredTypeIdentifier) { sourceURL, error in
                if let error {
                    self.logger.fail(
                        "The provider could not load audio for \(candidate.preferredTypeIdentifier).",
                        stage: "LOAD_ITEM_BEGIN",
                        error: error
                    )
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: candidate.preferredTypeIdentifier,
                        underlying: error
                    ))
                    return
                }

                guard let sourceURL else {
                    self.logger.fail(
                        "The provider did not return a file URL.",
                        stage: "LOAD_ITEM_BEGIN"
                    )
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: candidate.preferredTypeIdentifier,
                        underlying: nil
                    ))
                    return
                }

                guard sourceURL.isFileURL else {
                    self.logger.fail("The shared item did not resolve to a file URL.", stage: "LOAD_ITEM_BEGIN")
                    continuation.resume(throwing: ShareImportError.loadedItemWasNotFileURL)
                    return
                }

                self.logger.log("SECURITY_SCOPE_BEGIN", details: ["path": sourceURL.path])
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
                    let byteCount = try Self.byteCount(for: tempURL, fileManager: .default)
                    self.logger.log(
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
                        sourceTypeIdentifier: candidate.preferredTypeIdentifier,
                        byteCount: byteCount
                    ))
                } catch {
                    self.logger.fail(
                        "The provider copy into a temporary file failed.",
                        stage: "LOAD_ITEM_BEGIN",
                        error: error
                    )
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: candidate.preferredTypeIdentifier,
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
            stage: "ATTACHMENT_PROVIDER_FOUND",
            details: ["registeredTypeIdentifiers": seenTypeIdentifiers.joined(separator: ",")]
        )
        throw ShareImportError.noAudioAttachmentProviderFound(registeredTypeIdentifiers: seenTypeIdentifiers)
    }

    private static func byteCount(for url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
    }
}

struct SharedAudioInboxWriter {
    let configuration: SharedImportConfiguration
    let fileManager: FileManager
    let nowProvider: () -> Date
    let logger: ShareImportLogger
    let sharedContainerURLProvider: (() -> URL?)?

    init(
        configuration: SharedImportConfiguration,
        fileManager: FileManager = .default,
        nowProvider: @escaping () -> Date = Date.init,
        logger: ShareImportLogger,
        sharedContainerURLProvider: (() -> URL?)? = nil
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.nowProvider = nowProvider
        self.logger = logger
        self.sharedContainerURLProvider = sharedContainerURLProvider
    }

    func write(attachment: LoadedShareAttachment) throws -> SharedAudioInboxWriteResult {
        logger.log("COPY_TO_APP_GROUP_BEGIN", details: [
            "sourceFilename": attachment.sourceFilename,
            "sourceTypeIdentifier": attachment.sourceTypeIdentifier,
            "byteCount": String(attachment.byteCount)
        ])

        let containerURL = sharedContainerURLProvider?() ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: configuration.appGroupIdentifier)
        guard let containerURL else {
            logger.fail(
                "The app group container was unavailable.",
                stage: "COPY_TO_APP_GROUP_BEGIN",
                details: ["appGroupIdentifier": configuration.appGroupIdentifier]
            )
            throw ShareImportError.appGroupContainerUnavailable(appGroupIdentifier: configuration.appGroupIdentifier)
        }

        let inboxURL = containerURL.appendingPathComponent("SharedInbox", isDirectory: true)
        do {
            try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        } catch {
            logger.fail("The shared inbox directory could not be created.", stage: "COPY_TO_APP_GROUP_BEGIN", error: error)
            throw ShareImportError.failedToCreateInboxDirectory(underlying: error)
        }

        let normalizedFilename = try normalizeAudioFilename(
            originalFilename: attachment.sourceFilename,
            fallbackTypeIdentifier: attachment.sourceTypeIdentifier
        )
        let data = try Data(contentsOf: attachment.fileURL)
        let importID = makeImportID(fileData: data, normalizedFilename: normalizedFilename)
        let stagedFolderURL = inboxURL.appendingPathComponent(importID, isDirectory: true)
        let stagedAudioURL = stagedFolderURL.appendingPathComponent(normalizedFilename)
        let receiptURL = stagedFolderURL.appendingPathComponent("receipt.json")

        do {
            try fileManager.createDirectory(at: stagedFolderURL, withIntermediateDirectories: true)
        } catch {
            throw ShareImportError.failedToCreateInboxDirectory(underlying: error)
        }

        if fileManager.fileExists(atPath: stagedAudioURL.path) || fileManager.fileExists(atPath: receiptURL.path) {
            logger.fail("The destination file already exists.", stage: "COPY_TO_APP_GROUP_BEGIN", details: ["path": stagedFolderURL.path])
            throw ShareImportError.destinationFileAlreadyExists(path: stagedFolderURL.path)
        }

        do {
            try fileManager.copyItem(at: attachment.fileURL, to: stagedAudioURL)
        } catch {
            logger.fail("The shared audio file could not be copied into the app group container.", stage: "COPY_TO_APP_GROUP_BEGIN", error: error)
            throw ShareImportError.failedToCopySharedAudioIntoAppGroup(underlying: error)
        }

        let copiedByteCount = try Self.byteCount(for: stagedAudioURL, fileManager: fileManager)
        guard copiedByteCount > 0 else {
            logger.fail("The copied shared audio file was empty.", stage: "COPY_TO_APP_GROUP_BEGIN")
            throw ShareImportError.copiedFileIsEmpty
        }

        logger.log("COPY_TO_APP_GROUP_SUCCESS", details: [
            "destinationFilename": stagedAudioURL.lastPathComponent,
            "byteCount": String(copiedByteCount)
        ])

        let record = SharedAudioInboxRecord(
            importID: importID,
            sourceFilename: attachment.sourceFilename,
            normalizedFilename: normalizedFilename,
            stagedAudioFilename: normalizedFilename,
            sourceTypeIdentifier: attachment.sourceTypeIdentifier,
            byteCount: copiedByteCount,
            stagedAtISO8601: SharedRecordingReceiptISO8601Formatter.value.string(from: nowProvider())
        )

        do {
            let receiptData = try JSONEncoder().encode(record)
            try receiptData.write(to: receiptURL, options: .atomic)
        } catch {
            logger.fail("The shared audio manifest could not be persisted.", stage: "MANIFEST_WRITE_SUCCESS", error: error)
            throw ShareImportError.failedToPersistSharedAudioManifest(underlying: error)
        }

        logger.log("MANIFEST_WRITE_SUCCESS", details: [
            "importID": importID,
            "receiptFilename": receiptURL.lastPathComponent
        ])

        return SharedAudioInboxWriteResult(
            importID: importID,
            stagedFolderURL: stagedFolderURL,
            receiptURL: receiptURL,
            stagedAudioURL: stagedAudioURL,
            record: record
        )
    }

    private static func byteCount(for url: URL, fileManager: FileManager) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        return (attributes[.size] as? NSNumber)?.int64Value ?? 0
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
        let finalExtension: String
        if sourceExtension.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false {
            finalExtension = sourceExtension.lowercased()
        } else if let type = UTType(fallbackTypeIdentifier ?? ""), let inferred = type.preferredFilenameExtension, inferred.isEmpty == false {
            finalExtension = inferred.lowercased()
        } else {
            logger.fail("The shared file extension was missing and no audio type could be inferred.", stage: "COPY_TO_APP_GROUP_BEGIN")
            throw ShareImportError.missingFileExtension
        }

        return "\(finalStem).\(finalExtension)"
    }
}

private enum SharedRecordingReceiptISO8601Formatter {
    static let value: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
