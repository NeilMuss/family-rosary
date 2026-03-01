import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayerSequencePlayerSleeperTests: XCTestCase {
    func testPrayerSequencePlayerCallsInjectedSleeperBetweenItems() async throws {
        let playback = PlaybackClientSpy()
        let sleeper = RecordingSleeper()
        let player = PrayerSequencePlayer(playback: playback, sleeper: sleeper)

        let steps: [PrayerSequenceStep] = [
            .play(asset: AudioAssetRef(id: "one", url: URL(fileURLWithPath: "/tmp/one.m4a")), prompt: nil),
            .pause(ms: 400, prompt: nil),
            .play(asset: AudioAssetRef(id: "two", url: URL(fileURLWithPath: "/tmp/two.m4a")), prompt: nil),
            .pause(ms: 250, prompt: nil)
        ]

        try await player.play(steps: steps, onPromptChanged: { _ in })

        XCTAssertEqual(playback.playCalls.map(\.path), ["/tmp/one.m4a", "/tmp/two.m4a"])
        XCTAssertEqual(sleeper.sleepCalls, [400, 250])
    }

    func testImmediateSleeperAllowsPlaybackSequenceToComplete() async throws {
        let playback = PlaybackClientSpy()
        let player = PrayerSequencePlayer(playback: playback, sleeper: ImmediateSleeper())

        let steps: [PrayerSequenceStep] = [
            .play(asset: AudioAssetRef(id: "one", url: URL(fileURLWithPath: "/tmp/one.m4a")), prompt: nil),
            .pause(ms: 1000, prompt: nil),
            .play(asset: AudioAssetRef(id: "two", url: URL(fileURLWithPath: "/tmp/two.m4a")), prompt: nil),
            .pause(ms: 1000, prompt: nil)
        ]

        try await player.play(steps: steps, onPromptChanged: { _ in })

        XCTAssertEqual(playback.playCalls.map(\.path), ["/tmp/one.m4a", "/tmp/two.m4a"])
    }
}

private final class PlaybackClientSpy: AudioPlaybackClient {
    private(set) var playCalls: [URL] = []
    private(set) var isPlaying = false

    func play(url: URL) async throws {
        isPlaying = true
        playCalls.append(url)
        isPlaying = false
    }

    func play(url: URL, startSec: Double, endSec: Double) async throws {
        _ = startSec
        _ = endSec
        try await play(url: url)
    }

    func stop() {
        isPlaying = false
    }
}

private final class RecordingSleeper: Sleeper {
    private(set) var sleepCalls: [Int] = []

    func sleep(ms: Int) async {
        sleepCalls.append(ms)
    }
}
