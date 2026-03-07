import Foundation

struct AppCompositionRoot {
    private let isPreviewRuntime: Bool

    init(isPreviewRuntime: Bool = PreviewRuntime.isRunningForPreviews) {
        self.isPreviewRuntime = isPreviewRuntime
        #if DEBUG
        print("PreviewRuntime.isRunningForPreviews=\(PreviewRuntime.isRunningForPreviews)")
        print("AppCompositionRoot isPreviewRuntime=\(isPreviewRuntime)")
        if isPreviewRuntime {
            Self.logPreviewModeOnce()
        }
        #endif
    }

    func makeAudioRecorderClient() -> AudioRecorderClient {
        if isPreviewRuntime {
            return PreviewAudioRecorderClient()
        }
        return AVAudioRecorderClient()
    }

    func makeAudioPlaybackClient() -> AudioPlaybackClient {
        if isPreviewRuntime {
            return PreviewAudioPlaybackClient()
        }
        return AVAudioClipPlaybackClient()
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
        if isPreviewRuntime {
            return PreviewUtteranceListener()
        }
        return EnergyUtteranceListener()
    }

    func makeMicrophonePermissionClient() -> MicrophonePermissionClient {
        if isPreviewRuntime {
            return PreviewMicrophonePermissionClient()
        }
        return AVAudioSessionMicrophonePermissionClient()
    }

    func makeMicrophoneLevelMonitor() -> MicrophoneLevelMonitoring {
        if isPreviewRuntime {
            return PreviewMicrophoneLevelMonitor()
        }
        return AVAudioEngineMicrophoneLevelMonitor()
    }

    func makePrayerSequencePlayer() -> PrayerSequencePlaying {
        let catalog: PrayerClipCatalog? = isPreviewRuntime ? nil : makePrayerClipCatalog()
        return PrayerSequencePlayer(
            playback: makeAudioPlaybackClient(),
            sleeper: makeSleeper(),
            utteranceListener: makeUtteranceListener(),
            clipCatalog: catalog
        )
    }

    private func makePrayerClipCatalog() -> PrayerClipCatalog {
        let catalog = StaticPrayerClipCatalog()
        #if DEBUG
        let validator = BundlePrayerClipValidator()
        let errors = validator.validate(clips: catalog.allClips(), bundle: .main)
        for error in errors {
            print("PRAYER_CLIP_VALIDATION \(error)")
        }
        #endif
        return catalog
    }

    func makeBaseDirURLProvider() -> () -> URL {
        { FamilyRosaryPaths.baseDirURL() }
    }

    func makeRosaryPreferencesStore() -> RosaryPreferencesStore {
        UserDefaultsRosaryPreferencesStore()
    }

    func makeAvailablePrayerPartners() -> [PrayerPartner] {
        [
            PrayerPartner(id: "dad", displayName: "Dad"),
            PrayerPartner(id: "mom", displayName: "Mom")
        ]
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
    func makePrayViewModel(personID: String = "dad") -> PrayViewModel {
        return PrayViewModel(
            personID: personID,
            sequencePlayer: makePrayerSequencePlayer(),
            resolver: makeAudioFileResolver(),
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

    @MainActor
    func makeFamilyRosaryFlowViewModel() -> FamilyRosaryFlowViewModel {
        FamilyRosaryFlowViewModel(root: self)
    }

    @MainActor
    func makeMicrophoneCheckViewModel(
        onStartPrayer: @escaping (InteractiveCalibration?) -> Void,
        onBack: @escaping () -> Void
    ) -> MicrophoneCheckViewModel {
        MicrophoneCheckViewModel(
            microphonePermissionClient: makeMicrophonePermissionClient(),
            levelMonitor: makeMicrophoneLevelMonitor(),
            onStartPrayer: onStartPrayer,
            onBack: onBack
        )
    }

    #if DEBUG
    private static let previewModeLogOnce: Void = {
        print("PREVIEW_MODE=1 (skipping audio wiring)")
    }()

    private static func logPreviewModeOnce() {
        _ = previewModeLogOnce
    }
    #endif
}

private final class PreviewAudioPlaybackClient: AudioPlaybackClient {
    var isPlaying: Bool { false }

    func play(url: URL) async throws {}

    func play(url: URL, startSec: Double, endSec: Double) async throws {
        _ = startSec
        _ = endSec
    }

    func stop() {}
}

private final class PreviewAudioRecorderClient: AudioRecorderClient {
    var isRecording: Bool { false }
    var isPlaying: Bool { false }

    func startRecording(to url: URL) throws {
        _ = url
    }

    func stopRecording() throws {}

    func play(url: URL) throws {
        _ = url
    }

    func stopPlayback() {}
}

private struct PreviewMicrophonePermissionClient: MicrophonePermissionClient {
    func requestAccess() async -> Bool {
        true
    }
}

private struct PreviewUtteranceListener: UtteranceListener {
    func waitForUtterance(
        config: UtteranceConfig,
        onPhaseChanged: ((UtteranceDebugPhase) -> Void)?
    ) async throws -> UtteranceWaitResult {
        _ = config
        onPhaseChanged?(.userTurnCompleted)
        return .completedByUser
    }
}

private final class PreviewMicrophoneLevelMonitor: MicrophoneLevelMonitoring {
    private var task: Task<Void, Never>?

    func start(onLevelChanged: @escaping (Float) -> Void) throws {
        task?.cancel()
        task = Task {
            var level: Float = 0.05
            while !Task.isCancelled {
                onLevelChanged(level)
                level = level > 0.2 ? 0.05 : level + 0.02
                try? await Task.sleep(nanoseconds: 150_000_000)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }
}
