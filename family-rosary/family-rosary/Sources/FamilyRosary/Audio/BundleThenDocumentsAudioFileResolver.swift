import Foundation

struct BundleThenDocumentsAudioFileResolver: AudioFileResolving {
    private let recordingStore: RecordingStore
    private let defaultPartnerID: String

    init(
        bundle: Bundle = .main,
        baseDirURL: @escaping () -> URL = { FamilyRosaryPaths.baseDirURL() },
        finalisedRecordingStore: FinalisedImportedRecordingStoring,
        defaultPartnerID: String = PlaybackPartnerDefaults.defaultPartnerID
    ) {
        self.recordingStore = DefaultPartnerOverlayRecordingStore(
            finalisedRecordingStore: finalisedRecordingStore,
            bundle: bundle,
            baseDirURL: baseDirURL
        )
        self.defaultPartnerID = defaultPartnerID
    }

    func resolve(personID: String, token: String) -> URL? {
        guard let key = RecordingKey(playbackToken: token) else {
            return nil
        }

        return resolveRecording(
            partnerID: personID,
            key: key,
            recordingStore: recordingStore,
            defaultPartnerID: defaultPartnerID
        ).fileURL
    }
}
