import Foundation

enum SharedContainerLayout {
    static let diagnosticsDirectoryName = "SharedDiagnostics"
    static let logFilename = "entries.jsonl"
    static let inboxDirectoryName = "SharedInbox"
}

private final class SharedDiagnosticsLogMemoryCache {
    static let shared = SharedDiagnosticsLogMemoryCache()

    private var entriesByPath: [String: [SharedDiagnosticsEntry]] = [:]
    private let lock = NSLock()

    func entries(forPath path: String) -> [SharedDiagnosticsEntry]? {
        lock.lock()
        defer { lock.unlock() }
        return entriesByPath[path]
    }

    func setEntries(_ entries: [SharedDiagnosticsEntry], forPath path: String) {
        lock.lock()
        defer { lock.unlock() }
        entriesByPath[path] = entries
    }

    func removeAll() {
        lock.lock()
        defer { lock.unlock() }
        entriesByPath.removeAll()
    }
}

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
    case localDocumentsDirectoryUnavailable
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
        case .localDocumentsDirectoryUnavailable:
            return "Shared diagnostics failed: local Documents directory unavailable."
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
    let documentsDirectoryURLProvider: (() -> URL?)?
    let allowFallbackToLocalDocuments: Bool

    init(
        appGroupIdentifier: String,
        fileManager: FileManager = .default,
        sharedContainerURLProvider: (() -> URL?)? = nil,
        documentsDirectoryURLProvider: (() -> URL?)? = nil,
        allowFallbackToLocalDocuments: Bool = true
    ) {
        self.appGroupIdentifier = appGroupIdentifier
        self.fileManager = fileManager
        self.sharedContainerURLProvider = sharedContainerURLProvider
        self.documentsDirectoryURLProvider = documentsDirectoryURLProvider
        self.allowFallbackToLocalDocuments = allowFallbackToLocalDocuments
    }

    func append(_ entry: SharedDiagnosticsEntry) throws {
        let destination = try logDestination()
        let fileURL = try ensureDiagnosticsDirectory(using: destination.containerURL)
            .appendingPathComponent(SharedContainerLayout.logFilename)

        var entries = SharedDiagnosticsLogMemoryCache.shared.entries(forPath: fileURL.path) ?? []
        if destination.usingFallback, entries.isEmpty {
            entries.append(
                SharedDiagnosticsEntry(
                    timestampISO8601: Self.iso8601Formatter.string(from: Date()),
                    category: "LOGGING",
                    stage: "Fallback to local Documents directory (App Group unavailable)",
                    event: "INFO",
                    detail: nil
                )
            )
        }
        entries.append(entry)
        SharedDiagnosticsLogMemoryCache.shared.setEntries(entries, forPath: fileURL.path)

        do {
            try persist(entries: entries, to: fileURL)
        } catch {
            throw SharedDiagnosticsLogStoreError.failedToAppendLogEntry
        }
    }

    func loadEntries() throws -> [SharedDiagnosticsEntry] {
        let destination = try logDestination()
        let fileURL = try ensureDiagnosticsDirectory(using: destination.containerURL)
            .appendingPathComponent(SharedContainerLayout.logFilename)

        if let cachedEntries = SharedDiagnosticsLogMemoryCache.shared.entries(forPath: fileURL.path) {
            return cachedEntries
        }

        guard fileManager.fileExists(atPath: fileURL.path) else {
            return []
        }

        let loadedEntries = try readEntries(from: fileURL)
        SharedDiagnosticsLogMemoryCache.shared.setEntries(loadedEntries, forPath: fileURL.path)
        return loadedEntries
    }

    func clear() throws {
        let destination = try logDestination()
        let fileURL = try ensureDiagnosticsDirectory(using: destination.containerURL)
            .appendingPathComponent(SharedContainerLayout.logFilename)
        SharedDiagnosticsLogMemoryCache.shared.setEntries([], forPath: fileURL.path)
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

    func resolvedAppGroupIdentifier() throws -> String {
        let trimmed = appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            throw SharedDiagnosticsLogStoreError.appGroupIdentifierMissing
        }
        return trimmed
    }

    func containerURL() throws -> URL {
        let trimmed = try resolvedAppGroupIdentifier()

        let containerURL = sharedContainerURLProvider?() ?? fileManager.containerURL(forSecurityApplicationGroupIdentifier: trimmed)
        guard let containerURL else {
            throw SharedDiagnosticsLogStoreError.appGroupContainerUnavailable(appGroupIdentifier: trimmed)
        }
        return containerURL
    }

    func diagnosticsDirectoryURL() throws -> URL {
        let diagnosticsURL = try ensureDiagnosticsDirectory(using: containerURL())
        return diagnosticsURL
    }

    func logFileURL() throws -> URL {
        try diagnosticsDirectoryURL().appendingPathComponent(SharedContainerLayout.logFilename)
    }

    func activeLogFileURL() throws -> URL {
        let destination = try logDestination()
        return try ensureDiagnosticsDirectory(using: destination.containerURL)
            .appendingPathComponent(SharedContainerLayout.logFilename)
    }

    func activeContainerURL() throws -> URL {
        try logDestination().containerURL
    }

    func isUsingFallbackLocation() throws -> Bool {
        try logDestination().usingFallback
    }

    private func logDestination() throws -> (containerURL: URL, usingFallback: Bool) {
        do {
            return (try containerURL(), false)
        } catch let error as SharedDiagnosticsLogStoreError {
            guard allowFallbackToLocalDocuments else {
                throw error
            }
        } catch {
            if allowFallbackToLocalDocuments == false {
                throw error
            }
        }

        if let documentsURL = documentsDirectoryURLProvider?()
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            return (documentsURL, true)
        }

        throw SharedDiagnosticsLogStoreError.localDocumentsDirectoryUnavailable
    }

    private func ensureDiagnosticsDirectory(using baseURL: URL) throws -> URL {
        let diagnosticsURL = baseURL.appendingPathComponent(SharedContainerLayout.diagnosticsDirectoryName, isDirectory: true)
        do {
            try fileManager.createDirectory(at: diagnosticsURL, withIntermediateDirectories: true)
        } catch {
            throw SharedDiagnosticsLogStoreError.failedToCreateLogDirectory
        }
        return diagnosticsURL
    }

    private func readEntries(from fileURL: URL) throws -> [SharedDiagnosticsEntry] {
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

    private func persist(entries: [SharedDiagnosticsEntry], to fileURL: URL) throws {
        let encoder = JSONEncoder()
        let serialized = try entries
            .map { entry -> String in
                let data = try encoder.encode(entry)
                guard let line = String(data: data, encoding: .utf8) else {
                    throw SharedDiagnosticsLogStoreError.failedToAppendLogEntry
                }
                return line
            }
            .joined(separator: "\n")

        let finalText = serialized.isEmpty ? "" : serialized + "\n"
        guard let data = finalText.data(using: .utf8) else {
            throw SharedDiagnosticsLogStoreError.failedToAppendLogEntry
        }

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            throw SharedDiagnosticsLogStoreError.failedToAppendLogEntry
        }
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
    static func resetInMemoryCacheForTesting() {
        SharedDiagnosticsLogMemoryCache.shared.removeAll()
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
