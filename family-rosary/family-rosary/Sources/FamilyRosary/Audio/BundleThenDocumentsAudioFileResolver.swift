import Foundation

struct BundleThenDocumentsAudioFileResolver: AudioFileResolving {
    private let bundle: Bundle
    private let baseDirURL: () -> URL
    private let extensionsByPriority = ["m4a", "wav"]

    init(
        bundle: Bundle = .main,
        baseDirURL: @escaping () -> URL = { FamilyRosaryPaths.baseDirURL() }
    ) {
        self.bundle = bundle
        self.baseDirURL = baseDirURL
    }

    func resolve(personID: String, token: String) -> URL? {
        let baseName = "\(personID)_\(token)"

        for ext in extensionsByPriority {
            if let bundleURL = bundle.url(
                forResource: baseName,
                withExtension: ext,
                subdirectory: "SeedAudio"
            ) {
                return bundleURL
            }
            if let bundleURL = bundle.url(
                forResource: baseName,
                withExtension: ext,
                subdirectory: "Resources/SeedAudio"
            ) {
                return bundleURL
            }
            if let bundleURL = bundle.url(forResource: baseName, withExtension: ext) {
                return bundleURL
            }
        }

        let rawAudioURL = baseDirURL().appendingPathComponent("raw_audio", isDirectory: true)
        for ext in extensionsByPriority {
            let documentsURL = rawAudioURL.appendingPathComponent("\(baseName).\(ext)")
            if FileManager.default.fileExists(atPath: documentsURL.path) {
                return documentsURL
            }
        }

        return nil
    }
}
