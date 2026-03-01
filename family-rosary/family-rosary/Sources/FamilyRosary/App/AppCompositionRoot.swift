import Foundation

struct AppCompositionRoot {
    func makeAudioRecorderClient() -> AudioRecorderClient {
        AVAudioRecorderClient()
    }

    func makeAudioPlaybackClient() -> AudioPlaybackClient {
        AVAudioPlaybackClient()
    }

    func makeAudioTrimResolver() -> AudioTrimResolver {
        AudioTrimResolver(
            sampleProvider: AVAudioFileSampleProvider(),
            trimmer: SilenceTrimmer(),
            cache: AudioTrimCache(),
            config: .default
        )
    }

    func makeAudioImportUseCase() -> AudioImporting {
        AudioImportUseCase(baseDirURL: makeBaseDirURLProvider())
    }

    func makeAudioFileResolver() -> AudioFileResolving {
        BundleThenDocumentsAudioFileResolver(baseDirURL: makeBaseDirURLProvider())
    }

    func makeSleeper() -> Sleeper {
        #if DEBUG
        return ImmediateSleeper()
        #else
        return RealSleeper()
        #endif
    }

    func makeUtteranceListener() -> UtteranceListener {
        EnergyUtteranceListener()
    }

    func makeMicrophonePermissionClient() -> MicrophonePermissionClient {
        AVAudioSessionMicrophonePermissionClient()
    }

    func makePrayerSequencePlayer(trimResolver: AudioTrimResolver) -> PrayerSequencePlaying {
        return PrayerSequencePlayer(
            playback: makeAudioPlaybackClient(),
            sleeper: makeSleeper(),
            utteranceListener: makeUtteranceListener(),
            trimPrefetcher: { url, onLog in
                Task {
                    await trimResolver.prefetch(url: url, onLog: onLog)
                }
            },
            cachedTrimLookup: { url in
                await trimResolver.getCachedTrim(for: url)
            }
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
        let trimResolver = makeAudioTrimResolver()
        return PrayViewModel(
            sequencePlayer: makePrayerSequencePlayer(trimResolver: trimResolver),
            resolver: makeAudioFileResolver(),
            trimPrewarmer: trimResolver,
            microphonePermissionClient: makeMicrophonePermissionClient()
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
