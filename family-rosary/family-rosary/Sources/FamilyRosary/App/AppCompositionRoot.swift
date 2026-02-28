import Foundation

struct AppCompositionRoot {
    func makeAudioRecorderClient() -> AudioRecorderClient {
        AVAudioRecorderClient()
    }

    func makeAudioPlaybackClient() -> AudioPlaybackClient {
        AVAudioPlaybackClient()
    }

    func makeAudioImportUseCase() -> AudioImporting {
        AudioImportUseCase(baseDirURL: makeBaseDirURLProvider())
    }

    func makeAudioFileResolver() -> AudioFileResolving {
        BundleThenDocumentsAudioFileResolver(baseDirURL: makeBaseDirURLProvider())
    }

    func makeSleeper() -> Sleeper {
        RealSleeper()
    }

    func makePrayerSequencePlayer() -> PrayerSequencePlaying {
        PrayerSequencePlayer(
            playback: makeAudioPlaybackClient(),
            sleeper: makeSleeper()
        )
    }

    func makeBaseDirURLProvider() -> () -> URL {
        { FamilyRosaryPaths.baseDirURL() }
    }

    @MainActor
    func makeRecordPrayerViewModel(
        personID: String,
        part: AudioRecordingPart,
        promptText: String,
        onDone: @escaping () -> Void
    ) -> RecordPrayerViewModel {
        RecordPrayerViewModel(
            personID: personID,
            part: part,
            promptText: promptText,
            recorder: makeAudioRecorderClient(),
            baseDirURL: makeBaseDirURLProvider(),
            onDone: onDone
        )
    }

    @MainActor
    func makeRecordPrayerView(
        personID: String,
        part: AudioRecordingPart,
        promptText: String,
        onDone: @escaping () -> Void
    ) -> RecordPrayerView {
        let viewModel = makeRecordPrayerViewModel(
            personID: personID,
            part: part,
            promptText: promptText,
            onDone: onDone
        )
        return RecordPrayerView(viewModel: viewModel)
    }

    @MainActor
    func makePrayViewModel() -> PrayViewModel {
        PrayViewModel(
            sequencePlayer: makePrayerSequencePlayer(),
            resolver: makeAudioFileResolver()
        )
    }

    @MainActor
    func makeImportAudioViewModel() -> ImportAudioViewModel {
        ImportAudioViewModel(importer: makeAudioImportUseCase())
    }

    @MainActor
    func makePrayView() -> PrayView {
        PrayView(
            prayViewModel: makePrayViewModel(),
            importViewModel: makeImportAudioViewModel()
        )
    }
}
