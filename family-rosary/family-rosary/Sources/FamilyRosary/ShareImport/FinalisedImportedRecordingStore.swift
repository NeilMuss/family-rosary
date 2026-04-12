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
        entries.removeAll { $0.id == recording.id }
        entries.append(recording)
        try persist(entries.sorted { $0.id < $1.id })
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
}
