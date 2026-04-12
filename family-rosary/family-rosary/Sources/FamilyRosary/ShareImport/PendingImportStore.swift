import Foundation

enum PendingImportStoreError: LocalizedError, Equatable {
    case failedToCreateDirectory
    case failedToLoad
    case failedToSave
    case failedToRemove(id: String)

    var errorDescription: String? {
        switch self {
        case .failedToCreateDirectory:
            return "Pending import store failed: could not create parent directory."
        case .failedToLoad:
            return "Pending import store failed: could not load pending imports."
        case .failedToSave:
            return "Pending import store failed: could not save pending imports."
        case let .failedToRemove(id):
            return "Pending import store failed: could not remove pending import \(id)."
        }
    }
}

protocol PendingImportStoring {
    func save(_ pendingImport: PendingImport) throws
    func all() throws -> [PendingImport]
    func remove(id: String) throws
}

struct FileBackedPendingImportStore: PendingImportStoring {
    let fileManager: FileManager
    let indexFileURL: URL

    init(fileManager: FileManager = .default, indexFileURL: URL) {
        self.fileManager = fileManager
        self.indexFileURL = indexFileURL
    }

    func save(_ pendingImport: PendingImport) throws {
        var entries = try all()
        entries.removeAll { $0.id == pendingImport.id }
        entries.append(pendingImport)
        try persist(entries.sorted { $0.id < $1.id })
    }

    func all() throws -> [PendingImport] {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: indexFileURL)
            return try JSONDecoder().decode([PendingImport].self, from: data)
                .sorted { $0.id < $1.id }
        } catch {
            throw PendingImportStoreError.failedToLoad
        }
    }

    func remove(id: String) throws {
        let existing = try all()
        let filtered = existing.filter { $0.id != id }
        guard filtered.count != existing.count else {
            return
        }

        do {
            try persist(filtered)
        } catch let error as PendingImportStoreError {
            throw error == .failedToSave ? .failedToRemove(id: id) : error
        } catch {
            throw PendingImportStoreError.failedToRemove(id: id)
        }
    }

    private func persist(_ entries: [PendingImport]) throws {
        do {
            try fileManager.createDirectory(at: indexFileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            throw PendingImportStoreError.failedToCreateDirectory
        }

        do {
            let data = try JSONEncoder().encode(entries)
            try data.write(to: indexFileURL, options: .atomic)
        } catch {
            throw PendingImportStoreError.failedToSave
        }
    }
}
