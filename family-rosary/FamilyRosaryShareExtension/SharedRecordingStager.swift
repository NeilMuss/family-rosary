import Foundation
import UniformTypeIdentifiers
import CryptoKit

struct SharedRecordingReceipt: Codable {
    let importID: String
    let sourceFilename: String
    let normalizedFilename: String
    let stagedAudioFilename: String
    let sourceTypeIdentifier: String?
    let byteCount: Int64
    let stagedAtISO8601: String
}

enum SharedRecordingStagerError: LocalizedError {
    case appGroupUnavailable
    case audioProviderNotFound
    case notAudio(typeIdentifier: String?)
    case loadRepresentationFailed
    case copiedFileIsEmpty
    case missingFileExtension

    var errorDescription: String? {
        switch self {
        case .appGroupUnavailable:
            return "The share extension could not access the app group container."
        case .audioProviderNotFound:
            return "Shared audio file could not be found in the share extension input."
        case let .notAudio(typeIdentifier):
            if let typeIdentifier {
                return "Family Rosary received a shared item, but it was not recognized as audio (\(typeIdentifier))."
            }
            return "Family Rosary received a shared item, but it was not recognized as audio."
        case .loadRepresentationFailed:
            return "Shared audio file could not be loaded from the share sheet provider."
        case .copiedFileIsEmpty:
            return "Shared audio file was copied to the app group, but the copy is empty (0 bytes)."
        case .missingFileExtension:
            return "The shared file extension was missing and no audio type could be inferred."
        }
    }
}

struct StagedSharedRecording {
    let importID: String
    let stagedFolderURL: URL
    let receiptURL: URL
}

struct SharedRecordingStager {
    let configuration: SharedImportConfiguration
    let fileManager: FileManager
    let nowProvider: () -> Date

    init(
        configuration: SharedImportConfiguration,
        fileManager: FileManager = .default,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.configuration = configuration
        self.fileManager = fileManager
        self.nowProvider = nowProvider
    }

    func stageFirstAudio(from inputItems: [NSExtensionItem]) async throws -> StagedSharedRecording {
        log("SESSION started")
        guard let containerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: configuration.appGroupIdentifier) else {
            log("FAIL app group container unavailable")
            throw SharedRecordingStagerError.appGroupUnavailable
        }

        let sharedInboxURL = containerURL.appendingPathComponent("SharedInbox", isDirectory: true)
        try fileManager.createDirectory(at: sharedInboxURL, withIntermediateDirectories: true)
        log("PASS ensured shared inbox at \(sharedInboxURL.path)")

        guard let (provider, typeIdentifier) = findAudioProvider(from: inputItems) else {
            if let firstType = firstSharedTypeIdentifier(from: inputItems) {
                log("FAIL shared item not recognized as audio type=\(firstType)")
                throw SharedRecordingStagerError.notAudio(typeIdentifier: firstType)
            }
            log("FAIL no shared provider found")
            throw SharedRecordingStagerError.audioProviderNotFound
        }

        let sourceURL = try await loadFileURL(from: provider, preferredTypeIdentifier: typeIdentifier)
        let sourceFilename = sourceURL.lastPathComponent
        guard typeIdentifier == nil || UTType(typeIdentifier ?? "")?.conforms(to: .audio) == true else {
            log("FAIL shared type did not conform to audio type=\(typeIdentifier ?? "nil")")
            throw SharedRecordingStagerError.notAudio(typeIdentifier: typeIdentifier)
        }
        log("PASS loaded shared source filename=\(sourceFilename)")

        let normalizedFilename = try normalizeAudioFilename(originalFilename: sourceFilename, fallbackTypeIdentifier: typeIdentifier)
        let data = try Data(contentsOf: sourceURL)
        let importID = makeImportID(fileData: data, normalizedFilename: normalizedFilename)
        let stagedFolderURL = sharedInboxURL.appendingPathComponent(importID, isDirectory: true)
        try fileManager.createDirectory(at: stagedFolderURL, withIntermediateDirectories: true)
        log("PASS created staged folder import=\(importID) path=\(stagedFolderURL.path)")

        let stagedAudioURL = stagedFolderURL.appendingPathComponent(normalizedFilename)
        if fileManager.fileExists(atPath: stagedAudioURL.path) {
            try fileManager.removeItem(at: stagedAudioURL)
        }
        try data.write(to: stagedAudioURL, options: .atomic)

        let byteCount = Int64(data.count)
        guard byteCount > 0 else {
            log("FAIL copied shared file is 0 bytes import=\(importID)")
            throw SharedRecordingStagerError.copiedFileIsEmpty
        }
        log("PASS copied shared file bytes=\(byteCount)")

        let receipt = SharedRecordingReceipt(
            importID: importID,
            sourceFilename: sourceFilename,
            normalizedFilename: normalizedFilename,
            stagedAudioFilename: normalizedFilename,
            sourceTypeIdentifier: typeIdentifier,
            byteCount: byteCount,
            stagedAtISO8601: SharedRecordingReceiptISO8601Formatter.value.string(from: nowProvider())
        )

        let receiptURL = stagedFolderURL.appendingPathComponent("receipt.json")
        let receiptData = try JSONEncoder().encode(receipt)
        try receiptData.write(to: receiptURL, options: .atomic)
        log("PASS wrote receipt path=\(receiptURL.path)")
        log("SESSION completed import=\(importID)")

        return StagedSharedRecording(importID: importID, stagedFolderURL: stagedFolderURL, receiptURL: receiptURL)
    }

    private func findAudioProvider(from inputItems: [NSExtensionItem]) -> (NSItemProvider, String?)? {
        for item in inputItems {
            for provider in item.attachments ?? [] {
                let preferredTypeIdentifier = provider.registeredTypeIdentifiers.first(where: { identifier in
                    UTType(identifier)?.conforms(to: .audio) == true
                })
                if let preferredTypeIdentifier {
                    return (provider, preferredTypeIdentifier)
                }
            }
        }

        for item in inputItems {
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.audio.identifier) {
                    return (provider, UTType.audio.identifier)
                }
            }
        }

        return nil
    }

    private func firstSharedTypeIdentifier(from inputItems: [NSExtensionItem]) -> String? {
        for item in inputItems {
            for provider in item.attachments ?? [] {
                if let first = provider.registeredTypeIdentifiers.first {
                    return first
                }
            }
        }
        return nil
    }

    private func loadFileURL(from provider: NSItemProvider, preferredTypeIdentifier: String?) async throws -> URL {
        let typeIdentifier = preferredTypeIdentifier ?? UTType.audio.identifier

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { url, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let url else {
                    continuation.resume(throwing: SharedRecordingStagerError.loadRepresentationFailed)
                    return
                }

                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(url.pathExtension)
                do {
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func makeImportID(fileData: Data, normalizedFilename: String) -> String {
        var data = Data(normalizedFilename.utf8)
        data.append(fileData)
        let hash = SHA256.hash(data: data)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private func normalizeAudioFilename(
        originalFilename: String,
        fallbackTypeIdentifier: String?
    ) throws -> String {
        let parsed = NSString(string: originalFilename)
        let sourceName = parsed.deletingPathExtension
        let sourceExtension = parsed.pathExtension

        let stem = sourceName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()

        let finalStem = stem.isEmpty ? "shared_audio" : stem

        let ext = sourceExtension.lowercased().isEmpty == false
            ? sourceExtension.lowercased()
            : (UTType(fallbackTypeIdentifier ?? "")?.preferredFilenameExtension?.lowercased() ?? "")

        guard ext.isEmpty == false else {
            throw SharedRecordingStagerError.missingFileExtension
        }

        return "\(finalStem).\(ext)"
    }

    private func log(_ message: String) {
        NSLog("SHARE_IMPORT_EXT %@", message)
    }
}

private enum SharedRecordingReceiptISO8601Formatter {
    static let value: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
