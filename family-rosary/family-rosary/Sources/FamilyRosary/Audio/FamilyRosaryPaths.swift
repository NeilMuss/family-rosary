import Foundation

enum FamilyRosaryPaths {
    static func baseDirURL() -> URL {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("FamilyRosary", isDirectory: true)
    }

    @discardableResult
    static func rawAudioDirURL(baseDirURL: URL? = nil) throws -> URL {
        let baseURL = baseDirURL ?? Self.baseDirURL()
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let rawAudioURL = baseURL.appendingPathComponent("raw_audio", isDirectory: true)
        try FileManager.default.createDirectory(at: rawAudioURL, withIntermediateDirectories: true)
        return rawAudioURL
    }

    static func fileURL(personID: String, part: AudioRecordingPart, baseDirURL: URL? = nil) throws -> URL {
        let rawAudioURL = try rawAudioDirURL(baseDirURL: baseDirURL)
        let filename = "\(personID)_\(part.filenameToken).wav"
        return rawAudioURL.appendingPathComponent(filename)
    }
}
