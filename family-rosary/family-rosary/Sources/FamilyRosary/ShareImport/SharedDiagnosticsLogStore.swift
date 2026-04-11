import Foundation

struct SharedDiagnosticsEntry: Codable, Equatable, Identifiable {
    let timestampISO8601: String
    let category: String
    let stage: String
    let event: String
    let detail: String?

    var id: String {
        "\(timestampISO8601)|\(category)|\(stage)|\(event)|\(detail ?? "")"
    }

    var formattedLine: String {
        var components = [timestampISO8601, category, stage, event]
        if let detail, detail.isEmpty == false {
            components.append(detail)
        }
        return components.joined(separator: " | ")
    }
}

enum SharedDiagnosticsLogStoreError: LocalizedError, Equatable {
    case appGroupIdentifierMissing
    case appGroupContainerUnavailable(appGroupIdentifier: String)
    case failedToCreateLogDirectory
    case failedToAppendLogEntry
    case failedToLoadLogEntries
    case failedToClearLogEntries

    var errorDescription: String? {
        switch self {
        case .appGroupIdentifierMissing:
            return "Shared diagnostics failed: app group identifier is missing."
        case let .appGroupContainerUnavailable(appGroupIdentifier):
            return "Shared diagnostics failed: app group container unavailable for \(appGroupIdentifier)."
        case .failedToCreateLogDirectory:
            return "Shared diagnostics failed: could not create diagnostics directory."
        case .failedToAppendLogEntry:
            return "Shared diagnostics failed: could not append log entry."
        case .failedToLoadLogEntries:
            return "Shared diagnostics failed: could not load log entries."
        case .failedToClearLogEntries:
            return "Shared diagnostics failed: could not clear log entries."
        }
    }
}

struct SharedDiagnosticsLogStore {
    let appGroupIdentifier: String
    let fileManager: FileManager
    let sharedContainerURLProvider: (() -> URL?)?

    init(
        appGroupIdentifier: String,
        fileManager: FileManager = .default,
        sharedContainerURLProvider: (() -> URL?)? = nil
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
        self.sharedContainerURLProvider = sharedContainerURLProvider
    }

    func append(_ entry: SharedDiagnosticsEntry) throws {
        let fileURL = try logFileURL()
        let data = try JSONEncoder().encode(entry)

        if fileManager.fileExists(atPath: fileURL.path) == false {
            fileManager.createFile(atPath: fileURL.path, contents: nil)
        }

        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            throw SharedDiagnosticsLogStoreError.failedToAppendLogEntry
        }

        do {
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.write(contentsOf: Data([0x0A]))
            try handle.close()
        } catch {
            try? handle.close()
            throw SharedDiagnosticsLogStoreError.failedToAppendLogEntry
        }
    }

    func loadEntries() throws -> [SharedDiagnosticsEntry] {
        let fileURL = try logFileURL()
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        do {
            let content = try String(contentsOf: fileURL, encoding: .utf8)
            let lines = content.split(separator: "\n").map(String.init)
            let decoder = JSONDecoder()
            return try lines.compactMap { line in
                guard let data = line.data(using: .utf8) else { return nil }
                return try decoder.decode(SharedDiagnosticsEntry.self, from: data)
            }
        } catch {
            throw SharedDiagnosticsLogStoreError.failedToLoadLogEntries
        }
    }

    func clear() throws {
        let fileURL = try logFileURL()
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw SharedDiagnosticsLogStoreError.failedToClearLogEntries
        }
    }

    func copyAllText() throws -> String {
        try loadEntries().map(\.formattedLine).joined(separator: "\n")
    }

    private func logFileURL() throws -> URL {
        let trimmed = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw SharedDiagnosticsLogStoreError.appGroupIdentifierMissing
        }

        let containerURL = sharedContainerURLProvider?() ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: trimmed)
        guard let containerURL else {
            throw SharedDiagnosticsLogStoreError.appGroupContainerUnavailable(appGroupIdentifier: trimmed)
        }

        let diagnosticsURL = containerURL.appendingPathComponent("SharedDiagnostics", isDirectory: true)
        do {
            try fileManager.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
        } catch {
            throw SharedDiagnosticsLogStoreError.failedToCreateLogDirectory
        }

        return diagnosticsURL.appendingPathComponent("entries.jsonl")
    }
}

struct SharedDiagnosticsLogger {
    let category: String
    let store: SharedDiagnosticsLogStore
    let nowProvider: () -> Date
    let mirrorToDebugLog: Bool

    init(
        category: String,
        store: SharedDiagnosticsLogStore,
        nowProvider: @escaping () -> Date = Date.init,
        mirrorToDebugLog: Bool = true
    ) {
        self.category = category
        self.store = store
        self.nowProvider = nowProvider
        self.mirrorToDebugLog = mirrorToDebugLog
    }

    func log(stage: String, event: String, detail: String? = nil) {
        let entry = SharedDiagnosticsEntry(
            timestampISO8601: Self.iso8601Formatter.string(from: nowProvider()),
            category: category,
            stage: stage,
            event: event,
            detail: detail
        )

        do {
            try store.append(entry)
        } catch {
            DebugLog.shared.log("SHARE_INBOX LOG_WRITE_FAIL \(error.localizedDescription)")
        }

        if mirrorToDebugLog {
            DebugLog.shared.log(entry.formattedLine)
        }
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
