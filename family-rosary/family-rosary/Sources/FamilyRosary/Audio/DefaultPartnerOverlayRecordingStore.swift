import Foundation

struct DefaultPartnerOverlayRecordingStore: RecordingStore {
    let finalisedRecordingStore: FinalisedImportedRecordingStoring
    let bundle: Bundle
    let baseDirURL: () -> URL
    let fileManager: FileManager

    private let extensionsByPriority = ["m4a", "wav"]

    init(
        finalisedRecordingStore: FinalisedImportedRecordingStoring,
        bundle: Bundle = .main,
        baseDirURL: @escaping () -> URL = { FamilyRosaryPaths.baseDirURL() },
        fileManager: FileManager = .default
    ) {
        self.finalisedRecordingStore = finalisedRecordingStore
        self.bundle = bundle
        self.baseDirURL = baseDirURL
        self.fileManager = fileManager
    }

    func find(partnerID: String, key: RecordingKey) -> Recording? {
        if let imported = findImportedRecording(partnerID: partnerID, key: key) {
            return imported
        }

        if let fileBacked = findFileBackedRecording(partnerID: partnerID, key: key) {
            return fileBacked
        }

        return nil
    }

    private func findImportedRecording(partnerID: String, key: RecordingKey) -> Recording? {
        let recordings = ((try? finalisedRecordingStore.all()) ?? [])
            .filter { $0.partnerID == partnerID && $0.matchesPlaybackKey(key) }
            .sorted { lhs, rhs in
                if lhs.finalisedAtISO8601 != rhs.finalisedAtISO8601 {
                    return lhs.finalisedAtISO8601 > rhs.finalisedAtISO8601
                }
                return lhs.id > rhs.id
            }

        guard let recording = recordings.first,
              fileManager.fileExists(atPath: recording.libraryFileURL.path) else {
            return nil
        }

        return Recording(
            partnerID: partnerID,
            key: key,
            fileURL: recording.libraryFileURL
        )
    }

    private func findFileBackedRecording(partnerID: String, key: RecordingKey) -> Recording? {
        for token in key.candidateFilenameTokens {
            for ext in extensionsByPriority {
                let rawURL = baseDirURL()
                    .appendingPathComponent("raw_audio", isDirectory: true)
                    .appendingPathComponent("\(partnerID)_\(token).\(ext)")
                if fileManager.fileExists(atPath: rawURL.path) {
                    return Recording(partnerID: partnerID, key: key, fileURL: rawURL)
                }
            }

            for ext in extensionsByPriority {
                if let bundleURL = bundle.url(
                    forResource: "\(partnerID)_\(token)",
                    withExtension: ext,
                    subdirectory: "SeedAudio"
                ) ?? bundle.url(
                    forResource: "\(partnerID)_\(token)",
                    withExtension: ext,
                    subdirectory: "Resources/SeedAudio"
                ) ?? bundle.url(
                    forResource: "\(partnerID)_\(token)",
                    withExtension: ext
                ) {
                    return Recording(partnerID: partnerID, key: key, fileURL: bundleURL)
                }
            }
        }

        return nil
    }
}

private extension FinalisedImportedRecording {
    func matchesPlaybackKey(_ key: RecordingKey) -> Bool {
        guard prayer == key.prayer else {
            return false
        }

        switch prayerPart {
        case .apostlesCreed:
            return key.prayer == .apostlesCreed
        case .ourFatherLead:
            return key.part == .lead
        case .ourFatherResponse:
            return key.part == .response
        case .hailMaryLead:
            return key.part == .lead
        case .hailMaryResponse:
            return key.part == .response
        case .gloryBeLead:
            return key.part == .lead
        case .gloryBeResponse:
            return key.part == .response
        case .fatima:
            return key.part == .full
        case .hailHolyQueenLead:
            return key.part == .lead
        case .hailHolyQueenResponse:
            return key.part == .response
        case .hailHolyQueenClosing:
            return key.part == .closingLead
        }
    }
}
