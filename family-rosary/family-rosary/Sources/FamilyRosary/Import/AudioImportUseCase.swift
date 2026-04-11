import Foundation

protocol AudioImporting {
    func `import`(sourceURL: URL, personID: String, slot: ImportSlot) async throws -> URL
}

enum AudioImportError: LocalizedError {
    case missingFileExtension
    case canonicalizationFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .missingFileExtension:
            return "Import failed: selected file must have an extension."
        case let .canonicalizationFailed(reason):
            return "Import failed: \(reason)"
        }
    }
}

final class AudioImportUseCase: AudioImporting {
    private let baseDirURL: () -> URL
    private let audioPreparationService: ImportedAudioPreparing

    init(
        baseDirURL: @escaping () -> URL = { FamilyRosaryPaths.baseDirURL() },
        audioPreparationService: ImportedAudioPreparing
    ) {
        self.baseDirURL = baseDirURL
        self.audioPreparationService = audioPreparationService
    }

    func `import`(sourceURL: URL, personID: String, slot: ImportSlot) async throws -> URL {
        let ext = sourceURL.pathExtension.lowercased()
        guard !ext.isEmpty else {
            throw AudioImportError.missingFileExtension
        }

        let destinationURL = try FamilyRosaryPaths.fileURL(
            personID: personID,
            token: slot.audioPart.filenameToken,
            ext: CanonicalAudioFormat.speech.fileExtension,
            baseDirURL: baseDirURL()
        )

        do {
            let preparedAudio = try await audioPreparationService.prepare(
                sourceURL: sourceURL,
                destinationURL: destinationURL
            )
            #if DEBUG
            DebugLog.shared.log(
                "IMPORT_AUDIO_CANONICALIZED | person=\(personID) | slot=\(slot.audioPart.filenameToken) | path=\(preparedAudio.fileURL.path) | strategy=\(preparedAudio.strategy) | bytes=\(preparedAudio.inspection.fileSizeBytes) | duration_seconds=\(String(format: "%.2f", preparedAudio.inspection.durationSeconds))"
            )
            #endif
            return preparedAudio.fileURL
        } catch let error as LocalizedError {
            throw AudioImportError.canonicalizationFailed(reason: error.errorDescription ?? error.localizedDescription)
        } catch {
            throw AudioImportError.canonicalizationFailed(reason: error.localizedDescription)
        }
    }
}
