import AVFoundation
import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class AudioPlayerViewModelTests: XCTestCase {
    func testDisplayedTimeFormattingShowsTenths() {
        XCTAssertEqual(FinishImportView.tenthsFormatter(5.3), "0:05.3")
        XCTAssertEqual(FinishImportView.tenthsFormatter(72.7), "1:12.7")
    }

    func testPreviewPlayActionRetainsPlayerAndEntersPlayingState() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let factory = FakePreviewAudioPlayerFactory(player: player)
        let sessionController = FakePreviewAudioSessionController()
        let viewModel = AudioPlayerViewModel(
            sessionController: sessionController,
            playerFactory: factory
        )
        let url = URL(fileURLWithPath: "/tmp/preview-source.m4a")

        viewModel.load(url: url)
        factory.releaseStrongReference()
        viewModel.play()

        XCTAssertEqual(factory.loadedURLs, [url])
        XCTAssertEqual(viewModel.duration, 7.5)
        XCTAssertEqual(player.playCallCount, 1)
        XCTAssertTrue(viewModel.isPlaying)
        XCTAssertEqual(sessionController.configureCallCount, 1)
        XCTAssertNotNil(factory.weakPlayer)
    }

    func testPreviewStartFailureSurfacesExplicitError() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let viewModel = AudioPlayerViewModel(
            sessionController: FailingPreviewAudioSessionController(),
            playerFactory: FakePreviewAudioPlayerFactory(player: player)
        )

        viewModel.load(url: URL(fileURLWithPath: "/tmp/broken-preview.m4a"))
        viewModel.play()

        XCTAssertEqual(viewModel.errorMessage, "The app could not start preview playback: session unavailable")
        XCTAssertFalse(viewModel.isPlaying)
    }

    func testPreviewSetupFailureSurfacesExplicitError() {
        let viewModel = AudioPlayerViewModel(
            sessionController: FailingPreviewAudioSessionController(),
            playerFactory: FailingPreviewAudioPlayerFactory()
        )

        viewModel.load(url: URL(fileURLWithPath: "/tmp/broken-preview.m4a"))

        XCTAssertEqual(viewModel.errorMessage, "The app could not prepare the preview for this recording.")
        XCTAssertEqual(viewModel.duration, 0)
    }

    func testRestartSeeksToTrimStart() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let viewModel = makeViewModel(player: player)

        viewModel.load(url: URL(fileURLWithPath: "/tmp/preview-source.m4a"))
        viewModel.incrementTrimStart()
        viewModel.incrementTrimStart()
        player.currentTime = 3.2

        viewModel.restart()

        XCTAssertEqual(player.currentTime, viewModel.trimStart, accuracy: 0.001)
        XCTAssertEqual(viewModel.currentTime, viewModel.trimStart, accuracy: 0.001)
        XCTAssertTrue(viewModel.isPlaying)
    }

    func testPreviewStopsAtTrimEnd() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let viewModel = makeViewModel(player: player)

        viewModel.load(url: URL(fileURLWithPath: "/tmp/preview-source.m4a"))
        for _ in 0..<5 { viewModel.decrementTrimEnd() }
        viewModel.restart()
        player.currentTime = viewModel.trimEnd

        viewModel.processProgressTickForTesting()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertTrue(viewModel.didReachTrimEnd)
        XCTAssertEqual(viewModel.currentTime, viewModel.trimEnd, accuracy: 0.001)
        XCTAssertEqual(player.currentTime, viewModel.trimEnd, accuracy: 0.001)
    }

    func testTrimChangesAffectSubsequentRestartPlayback() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let viewModel = makeViewModel(player: player)

        viewModel.load(url: URL(fileURLWithPath: "/tmp/preview-source.m4a"))
        viewModel.incrementTrimStart()
        viewModel.incrementTrimStart()
        let firstTrimStart = viewModel.trimStart
        viewModel.restart()
        XCTAssertEqual(player.currentTime, firstTrimStart, accuracy: 0.001)

        viewModel.incrementTrimStart()
        viewModel.incrementTrimStart()
        let secondTrimStart = viewModel.trimStart
        viewModel.restart()

        XCTAssertEqual(player.currentTime, secondTrimStart, accuracy: 0.001)
        XCTAssertNotEqual(firstTrimStart, secondTrimStart)
    }

    func testNaturalStopUpdatesPlayingStateAndLeavesPlayheadAtTrimEnd() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let viewModel = makeViewModel(player: player)

        viewModel.load(url: URL(fileURLWithPath: "/tmp/preview-source.m4a"))
        viewModel.restart()
        player.currentTime = viewModel.trimEnd

        viewModel.processProgressTickForTesting()

        XCTAssertFalse(viewModel.isPlaying)
        XCTAssertTrue(viewModel.didReachTrimEnd)
        XCTAssertEqual(viewModel.currentTime, viewModel.trimEnd, accuracy: 0.001)
    }

    private func makeViewModel(player: FakePreviewAudioPlayer) -> AudioPlayerViewModel {
        AudioPlayerViewModel(
            sessionController: FakePreviewAudioSessionController(),
            playerFactory: FakePreviewAudioPlayerFactory(player: player)
        )
    }
}

private final class FakePreviewAudioPlayer: PreviewAudioPlaying {
    var delegate: AVAudioPlayerDelegate?
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var isPlaying = false
    private(set) var playCallCount = 0
    private let playResult: Bool

    init(duration: TimeInterval, playResult: Bool = true) {
        self.duration = duration
        self.playResult = playResult
    }

    func prepareToPlay() -> Bool { true }

    func play() -> Bool {
        playCallCount += 1
        isPlaying = playResult
        return playResult
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
    }
}

private final class FakePreviewAudioPlayerFactory: PreviewAudioPlayerBuilding {
    private var strongPlayer: FakePreviewAudioPlayer?
    weak var weakPlayer: FakePreviewAudioPlayer?
    private(set) var loadedURLs: [URL] = []

    init(player: FakePreviewAudioPlayer) {
        self.strongPlayer = player
        self.weakPlayer = player
    }

    func makePlayer(url: URL) throws -> any PreviewAudioPlaying {
        loadedURLs.append(url)
        guard let strongPlayer else {
            throw NSError(domain: "AudioPlayerViewModelTests", code: 2, userInfo: [NSLocalizedDescriptionKey: "player missing"])
        }
        return strongPlayer
    }

    func releaseStrongReference() {
        strongPlayer = nil
    }
}

private final class FakePreviewAudioSessionController: PreviewAudioSessionControlling {
    private(set) var configureCallCount = 0

    func configureForPlayback() throws {
        configureCallCount += 1
    }
}

private struct FailingPreviewAudioSessionController: PreviewAudioSessionControlling {
    func configureForPlayback() throws {
        throw NSError(domain: "AudioPlayerViewModelTests", code: 3, userInfo: [NSLocalizedDescriptionKey: "session unavailable"])
    }
}

private struct FailingPreviewAudioPlayerFactory: PreviewAudioPlayerBuilding {
    func makePlayer(url: URL) throws -> any PreviewAudioPlaying {
        _ = url
        throw NSError(domain: "AudioPlayerViewModelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "broken"])
    }
}
