import Foundation

enum FamilyRosaryPaths {
    nonisolated static func baseDirURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("FamilyRosary", isDirectory: true)
    }

    @discardableResult
    nonisolated static func rawAudioDirURL(baseDirURL: URL? = nil) throws -> URL {
        let baseURL = baseDirURL ?? Self.baseDirURL()
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let rawAudioURL = baseURL.appendingPathComponent("raw_audio", isDirectory: true)
        try FileManager.default.createDirectory(at: rawAudioURL, withIntermediateDirectories: true)
        return rawAudioURL
    }

    @discardableResult
    nonisolated static func importedSharedAudioDirURL(baseDirURL: URL? = nil) throws -> URL {
        let baseURL = baseDirURL ?? Self.baseDirURL()
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let importedURL = baseURL.appendingPathComponent("imported_shared_audio", isDirectory: true)
        try FileManager.default.createDirectory(at: importedURL, withIntermediateDirectories: true)
        return importedURL
    }

    nonisolated static func importedRecordingIndexFileURL(baseDirURL: URL? = nil) -> URL {
        let baseURL = baseDirURL ?? Self.baseDirURL()
        return baseURL
            .appendingPathComponent("imports", isDirectory: true)
            .appendingPathComponent("imported_recordings.json")
    }

    nonisolated static func fileURL(personID: String, part: AudioRecordingPart, baseDirURL: URL? = nil) throws -> URL {
        let rawAudioURL = try rawAudioDirURL(baseDirURL: baseDirURL)
        let filename = "\(personID)_\(part.filenameToken).wav"
        return rawAudioURL.appendingPathComponent(filename)
    }

    nonisolated static func fileURL(
        personID: String,
        token: String,
        ext: String,
        baseDirURL: URL? = nil
    ) throws -> URL {
        let rawAudioURL = try rawAudioDirURL(baseDirURL: baseDirURL)
        let filename = "\(personID)_\(token).\(ext)"
        return rawAudioURL.appendingPathComponent(filename)
    }

    nonisolated static func fileURLIfExists(personID: String, part: AudioRecordingPart, baseDirURL: URL? = nil) -> URL? {
        let baseURL = baseDirURL ?? Self.baseDirURL()
        let rawAudioURL = baseURL.appendingPathComponent("raw_audio", isDirectory: true)
        let basename = "\(personID)_\(part.filenameToken)"
        let candidates = [
            rawAudioURL.appendingPathComponent("\(basename).m4a"),
            rawAudioURL.appendingPathComponent("\(basename).wav")
        ]

        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }

        return nil
    }
}
