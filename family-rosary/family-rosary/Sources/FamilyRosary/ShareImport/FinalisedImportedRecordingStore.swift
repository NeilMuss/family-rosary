import Foundation

enum FinalisedImportedRecordingStoreError: LocalizedError, Equatable {
    case failedToCreateDirectory
    case failedToLoad
    case failedToSave

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "Finalised imported recording store failed: could not create parent directory."
        case .failedToLoad:
            return "Finalised imported recording store failed: could not load recordings."
        case .failedToSave:
            return "Finalised imported recording store failed: could not save recordings."
        }
    }
}

protocol FinalisedImportedRecordingStoring {
    func save(_ recording: FinalisedImportedRecording) throws
    func all() throws -> [FinalisedImportedRecording]
    func delete(partnerID: String, prayerLineKey: PrayerLineKey) throws
}

struct FileBackedFinalisedImportedRecordingStore: FinalisedImportedRecordingStoring {
    let fileManager: FileManager
    let indexFileURL: URL

    init(fileManager: FileManager = .default, indexFileURL: URL) {
        self.fileManager = fileManager
        self.indexFileURL = indexFileURL
    }

    func save(_ recording: FinalisedImportedRecording) throws {
        var entries = try all()
        let replacedEntries = entries.filter {
            $0.id != recording.id &&
            $0.partnerID == recording.partnerID &&
            $0.prayerPart.domainPrayerLineKey == recording.prayerPart.domainPrayerLineKey
        }
        entries.removeAll {
            $0.id == recording.id ||
            (
                $0.partnerID == recording.partnerID &&
                $0.prayerPart.domainPrayerLineKey == recording.prayerPart.domainPrayerLineKey
            )
        }
        entries.append(recording)
        try persist(entries.sorted { $0.id < $1.id })
        removeFiles(for: replacedEntries, preserving: recording.libraryFileURL)
    }

    func all() throws -> [FinalisedImportedRecording] {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            return try JSONDecoder().decode([FinalisedImportedRecording].self, from: data)
                .sorted { $0.id < $1.id }
        } catch {
            throw FinalisedImportedRecordingStoreError.failedToLoad
        }
    }

    func delete(partnerID: String, prayerLineKey: PrayerLineKey) throws {
        var entries = try all()
        let removedEntries = entries.filter {
            $0.partnerID == partnerID && $0.prayerPart.domainPrayerLineKey == prayerLineKey
        }
        guard removedEntries.isEmpty == false else { return }

        entries.removeAll {
            $0.partnerID == partnerID && $0.prayerPart.domainPrayerLineKey == prayerLineKey
        }
        try persist(entries)
        removeFiles(for: removedEntries)
    }

    private func persist(_ entries: [FinalisedImportedRecording]) throws {
        do {
            try fileManager.createDirectory(at: indexFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw FinalisedImportedRecordingStoreError.failedToCreateDirectory
        }

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: indexFileURL, options: .atomic)
        } catch {
            throw FinalisedImportedRecordingStoreError.failedToSave
        }
    }

    private func removeFiles(for entries: [FinalisedImportedRecording], preserving preservedURL: URL? = nil) {
        for url in Set(entries.map(\.libraryFileURL)) where url != preservedURL {
            try? fileManager.removeItem(at: url)
        }
    }
}

struct EmptyFinalisedImportedRecordingStore: FinalisedImportedRecordingStoring {
    func save(_ recording: FinalisedImportedRecording) throws {}
    func all() throws -> [FinalisedImportedRecording] { [] }
    func delete(partnerID: String, prayerLineKey: PrayerLineKey) throws {}
}
