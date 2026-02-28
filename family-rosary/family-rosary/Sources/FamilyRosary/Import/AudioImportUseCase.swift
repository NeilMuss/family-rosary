import Foundation

protocol AudioImporting {
    func `import`(sourceURL: URL, personID: String, slot: ImportSlot) throws -> URL
}

enum AudioImportError: LocalizedError {
    case missingFileExtension

    var errorDescription: String? {
        switch self {
        case .missingFileExtension:
            return "Selected file must have an extension."
        }
    }
}

final class AudioImportUseCase: AudioImporting {
    private let baseDirURL: () -> URL

    init(baseDirURL: @escaping () -> URL = { FamilyRosaryPaths.baseDirURL() }) {
        self.baseDirURL = baseDirURL
    }

    func `import`(sourceURL: URL, personID: String, slot: ImportSlot) throws -> URL {
        let ext = sourceURL.pathExtension.lowercased()
        guard !ext.isEmpty else {
            throw AudioImportError.missingFileExtension
        }

        let destinationURL = try FamilyRosaryPaths.fileURL(
            personID: personID,
            token: slot.audioPart.filenameToken,
            ext: ext,
            baseDirURL: baseDirURL()
        )
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)

        return destinationURL
    }
}
