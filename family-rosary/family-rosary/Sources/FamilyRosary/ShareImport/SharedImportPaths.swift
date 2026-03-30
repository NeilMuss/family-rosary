import Foundation
import UniformTypeIdentifiers

enum SharedImportPathsError: LocalizedError, Equatable {
    case appGroupIdentifierMissing
    case appGroupContainerUnavailable(appGroupIdentifier: String)
    case missingFileExtension

    var errorDescription: String? {
        switch self {
        case .appGroupIdentifierMissing:
            return "The share extension could not access the app group container because the app group identifier is missing."
        case let .appGroupContainerUnavailable(appGroupIdentifier):
            return "The share extension could not access the app group container (\(appGroupIdentifier))."
        case .missingFileExtension:
            return "The shared file extension was missing and no audio type could be inferred."
        }
    }
}

struct SharedImportPaths {
    let fileManager: FileManager
    let appGroupIdentifier: String
    let sharedContainerURLProvider: (() -> URL?)?

    init(
        fileManager: FileManager = .default,
        appGroupIdentifier: String,
        sharedContainerURLProvider: (() -> URL?)? = nil
    ) {
        self.fileManager = fileManager
        self.appGroupIdentifier = appGroupIdentifier
        self.sharedContainerURLProvider = sharedContainerURLProvider
    }

    func sharedContainerURL() throws -> URL {
        let trimmedIdentifier = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            throw SharedImportPathsError.appGroupIdentifierMissing
        }

        let containerURL = sharedContainerURLProvider?() ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: trimmedIdentifier)
        guard let containerURL else {
            throw SharedImportPathsError.appGroupContainerUnavailable(appGroupIdentifier: trimmedIdentifier)
        }

        return containerURL
    }

    @discardableResult
    func ensureSharedInboxDirectory() throws -> URL {
        let inboxURL = try sharedInboxDirectoryURL()
        try fileManager.createDirectory(at: inboxURL, withIntermediateDirectories: true)
        return inboxURL
    }

    func sharedInboxDirectoryURL() throws -> URL {
        try sharedContainerURL().appendingPathComponent("SharedInbox", isDirectory: true)
    }

    func stagedImportDirectoryURL(importID: String) throws -> URL {
        try sharedInboxDirectoryURL().appendingPathComponent(importID, isDirectory: true)
    }

    func receiptURL(importID: String) throws -> URL {
        try stagedImportDirectoryURL(importID: importID).appendingPathComponent("receipt.json")
    }

    static func normalizeAudioFilename(
        originalFilename: String,
        fallbackTypeIdentifier: String? = nil
    ) throws -> String {
        let parsed = NSString(string: originalFilename)
        let sourceName = parsed.deletingPathExtension
        let sourceExtension = parsed.pathExtension

        let stem = sanitizeFilenameComponent(sourceName)
        let ext = try preferredAudioExtension(
            sourceExtension: sourceExtension,
            fallbackTypeIdentifier: fallbackTypeIdentifier
        )

        return "\(stem).\(ext)"
    }

    private static func sanitizeFilenameComponent(_ raw: String) -> String {
        let folded = raw
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()

        if folded.isEmpty {
            return "shared_audio"
        }
        return folded
    }

    private static func preferredAudioExtension(
        sourceExtension: String,
        fallbackTypeIdentifier: String?
    ) throws -> String {
        let normalizedSourceExtension = sourceExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSourceExtension.isEmpty {
            return normalizedSourceExtension
        }

        if let fallbackTypeIdentifier,
           let type = UTType(fallbackTypeIdentifier),
           let inferred = type.preferredFilenameExtension,
           !inferred.isEmpty {
            return inferred.lowercased()
        }

        throw SharedImportPathsError.missingFileExtension
    }
}
