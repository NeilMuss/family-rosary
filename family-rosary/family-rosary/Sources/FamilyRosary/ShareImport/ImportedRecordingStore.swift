import Foundation

struct ImportedRecording: Codable, Equatable, Identifiable {
    let id: String
    let importID: String
    let filename: String
    let libraryRelativePath: String
    let durationSeconds: Double
    let importedAtISO8601: String
}

protocol ImportedRecordingStoring {
    func register(_ recording: ImportedRecording) throws
    func all() throws -> [ImportedRecording]
}

struct FileBackedImportedRecordingStore: ImportedRecordingStoring {
    let fileManager: FileManager
    let indexFileURL: URL

    init(
        fileManager: FileManager = .default,
        indexFileURL: URL
    ) {
        self.fileManager = fileManager
        self.indexFileURL = indexFileURL
    }

    func register(_ recording: ImportedRecording) throws {
        let directoryURL = indexFileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)

        var entries = try all()
        entries.append(recording)

        let data = try JSONEncoder().encode(entries)
        try data.write(to: indexFileURL, options: .atomic)
    }

    func all() throws -> [ImportedRecording] {
        guard fileManager.fileExists(atPath: indexFileURL.path) else {
            return []
        }

        let data = try Data(contentsOf: indexFileURL)
        return try JSONDecoder().decode([ImportedRecording].self, from: data)
    }
}
