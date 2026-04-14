import AVFoundation
import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class AudioPlayerViewModelTests: XCTestCase {
    func testPreviewUsesSameSourceForDurationAndPlayback() {
        let player = FakePreviewAudioPlayer(duration: 7.5)
        let factory = FakePreviewAudioPlayerFactory(player: player)
        let viewModel = AudioPlayerViewModel(playerFactory: factory)
        let url = URL(fileURLWithPath: "/tmp/preview-source.m4a")

        viewModel.load(url: url)
        viewModel.play()

        XCTAssertEqual(factory.loadedURLs, [url])
        XCTAssertEqual(viewModel.duration, 7.5)
        XCTAssertEqual(player.playCallCount, 1)
        XCTAssertTrue(viewModel.isPlaying)
    }

    func testPreviewSurfacesExplicitErrorWhenSetupFails() {
        let viewModel = AudioPlayerViewModel(
            playerFactory: FailingPreviewAudioPlayerFactory()
        )

        viewModel.load(url: URL(fileURLWithPath: "/tmp/broken-preview.m4a"))

        XCTAssertEqual(viewModel.errorMessage, "The app could not prepare the preview for this recording.")
        XCTAssertEqual(viewModel.duration, 0)
    }
}

private final class FakePreviewAudioPlayer: PreviewAudioPlaying {
    var delegate: AVAudioPlayerDelegate?
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var isPlaying = false
    private(set) var playCallCount = 0

    init(duration: TimeInterval) {
        self.duration = duration
    }

    func prepareToPlay() -> Bool { true }

    func play() -> Bool {
        playCallCount += 1
        isPlaying = true
        return true
    }

    func pause() {
        isPlaying = false
    }

    func stop() {
        isPlaying = false
    }
}

private final class FakePreviewAudioPlayerFactory: PreviewAudioPlayerBuilding {
    let player: FakePreviewAudioPlayer
    private(set) var loadedURLs: [URL] = []

    init(player: FakePreviewAudioPlayer) {
        self.player = player
    }

    func makePlayer(url: URL) throws -> any PreviewAudioPlaying {
        loadedURLs.append(url)
        return player
    }
}

private struct FailingPreviewAudioPlayerFactory: PreviewAudioPlayerBuilding {
    func makePlayer(url: URL) throws -> any PreviewAudioPlaying {
        _ = url
        throw NSError(domain: "AudioPlayerViewModelTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "broken"])
    }
}
