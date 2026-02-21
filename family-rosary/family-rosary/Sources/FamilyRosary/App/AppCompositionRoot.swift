import Foundation

struct AppCompositionRoot {
    func makeAudioRecorderClient() -> AudioRecorderClient {
        AVAudioRecorderClient()
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
}
