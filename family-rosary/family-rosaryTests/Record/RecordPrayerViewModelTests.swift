import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class RecordPrayerViewModelTests: XCTestCase {
    func testIdleTapStartsRecordingAndMovesToRecordingPhase() throws {
        let fakeRecorder = FakeAudioRecorderClient()
        let baseDir = temporaryBaseDir()
        let viewModel = makeViewModel(recorder: fakeRecorder, baseDir: baseDir)

        viewModel.onTapRecordOrStop()

        let expectedURL = try FamilyRosaryPaths.fileURL(personID: "dad", part: .hailMaryLead, baseDirURL: baseDir)
        XCTAssertEqual(fakeRecorder.startedURL, expectedURL)
        XCTAssertEqual(fakeRecorder.stopPlaybackCallCount, 1)
        XCTAssertEqual(viewModel.phase, .recording)
    }

    func testRecordingTapStopsThenMovesToReviewAndAutoPlays() throws {
        let fakeRecorder = FakeAudioRecorderClient()
        let baseDir = temporaryBaseDir()
        let viewModel = makeViewModel(recorder: fakeRecorder, baseDir: baseDir)

        viewModel.onTapRecordOrStop()
        viewModel.onTapRecordOrStop()

        let expectedURL = try FamilyRosaryPaths.fileURL(personID: "dad", part: .hailMaryLead, baseDirURL: baseDir)
        XCTAssertTrue(fakeRecorder.didStopRecording)
        XCTAssertEqual(viewModel.phase, .review(fileURL: expectedURL))
        XCTAssertEqual(fakeRecorder.playedURL, expectedURL)
        XCTAssertEqual(fakeRecorder.playCalls, [expectedURL])
    }

    func testReplayInReviewPlaysAgain() throws {
        let fakeRecorder = FakeAudioRecorderClient()
        let baseDir = temporaryBaseDir()
        let viewModel = makeViewModel(recorder: fakeRecorder, baseDir: baseDir)

        viewModel.onTapRecordOrStop()
        viewModel.onTapRecordOrStop()
        viewModel.onTapReplay()

        let expectedURL = try FamilyRosaryPaths.fileURL(personID: "dad", part: .hailMaryLead, baseDirURL: baseDir)
        XCTAssertEqual(viewModel.phase, .review(fileURL: expectedURL))
        XCTAssertEqual(fakeRecorder.playCalls, [expectedURL, expectedURL])
    }

    func testStartingRecordingStopsPlayback() {
        let fakeRecorder = FakeAudioRecorderClient()
        let baseDir = temporaryBaseDir()
        let viewModel = makeViewModel(recorder: fakeRecorder, baseDir: baseDir)

        viewModel.onTapRecordOrStop()

        XCTAssertEqual(fakeRecorder.stopPlaybackCallCount, 1)
        XCTAssertEqual(viewModel.phase, .recording)
    }

    func testRedoStopsPlaybackDeletesExistingFileAndReturnsToIdle() throws {
        let fakeRecorder = FakeAudioRecorderClient()
        let baseDir = temporaryBaseDir()
        let targetURL = try FamilyRosaryPaths.fileURL(personID: "dad", part: .hailMaryLead, baseDirURL: baseDir)
        try Data("test".utf8).write(to: targetURL)

        let viewModel = makeViewModel(recorder: fakeRecorder, baseDir: baseDir)
        viewModel.phase = .review(fileURL: targetURL)

        viewModel.onTapRedo()

        XCTAssertEqual(fakeRecorder.stopPlaybackCallCount, 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetURL.path))
        XCTAssertEqual(viewModel.phase, .idle)
    }

    func testKeepInvokesOnDone() {
        let fakeRecorder = FakeAudioRecorderClient()
        let baseDir = temporaryBaseDir()
        var onDoneCallCount = 0

        let viewModel = RecordPrayerViewModel(
            personID: "dad",
            part: .hailMaryLead,
            promptText: "Say a Hail Mary for Mom.",
            recorder: fakeRecorder,
            baseDirURL: { baseDir },
            onDone: { onDoneCallCount += 1 }
        )

        viewModel.onTapKeep()

        XCTAssertEqual(onDoneCallCount, 1)
    }

    private func makeViewModel(recorder: FakeAudioRecorderClient, baseDir: URL) -> RecordPrayerViewModel {
        RecordPrayerViewModel(
            personID: "dad",
            part: .hailMaryLead,
            promptText: "Say a Hail Mary for Mom.",
            recorder: recorder,
            baseDirURL: { baseDir },
            onDone: {}
        )
    }

    private func temporaryBaseDir() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        return url
    }
}

private final class FakeAudioRecorderClient: AudioRecorderClient {
    private(set) var startedURL: URL?
    private(set) var didStopRecording = false
    private(set) var playedURL: URL?
    private(set) var playCalls: [URL] = []
    private(set) var stopPlaybackCallCount = 0

    private(set) var isRecording = false
    private(set) var isPlaying = false

    func startRecording(to url: URL) throws {
        startedURL = url
        isRecording = true
    }

    func stopRecording() throws {
        didStopRecording = true
        isRecording = false
    }

    func play(url: URL) throws {
        playedURL = url
        playCalls.append(url)
        isPlaying = true
    }

    func stopPlayback() {
        stopPlaybackCallCount += 1
        isPlaying = false
    }
}
