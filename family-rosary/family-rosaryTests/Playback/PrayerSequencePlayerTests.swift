import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayerSequencePlayerTests: XCTestCase {
    func testPlayRunsInOrderWithPauses() async throws {
        var events: [String] = []
        let playback = FakeAudioPlaybackClient(eventSink: { events.append($0) })
        let sleeper = FakeSleeper(eventSink: { events.append($0) })
        let player = PrayerSequencePlayer(playback: playback, sleeper: sleeper)

        let stepA = PrayerPlaybackStep(url: URL(fileURLWithPath: "/tmp/A.wav"), pauseAfterMs: 400)
        let stepB = PrayerPlaybackStep(url: URL(fileURLWithPath: "/tmp/B.wav"), pauseAfterMs: 250)
        let stepC = PrayerPlaybackStep(url: URL(fileURLWithPath: "/tmp/C.wav"), pauseAfterMs: 0)

        try await player.play(steps: [stepA, stepB, stepC])

        XCTAssertEqual(playback.playCalls, [stepA.url, stepB.url, stepC.url])
        XCTAssertEqual(sleeper.sleepCalls, [400, 250, 0])
        XCTAssertEqual(
            events,
            [
                "play:/tmp/A.wav",
                "sleep:400",
                "play:/tmp/B.wav",
                "sleep:250",
                "play:/tmp/C.wav",
                "sleep:0"
            ]
        )
    }

    func testStopStopsPlayback() {
        let playback = FakeAudioPlaybackClient(eventSink: { _ in })
        let sleeper = FakeSleeper(eventSink: { _ in })
        let player = PrayerSequencePlayer(playback: playback, sleeper: sleeper)

        player.stop()

        XCTAssertEqual(playback.stopCallCount, 1)
    }
}

private final class FakeAudioPlaybackClient: AudioPlaybackClient {
    private let eventSink: (String) -> Void

    private(set) var playCalls: [URL] = []
    private(set) var stopCallCount = 0
    private(set) var isPlaying = false

    init(eventSink: @escaping (String) -> Void) {
        self.eventSink = eventSink
    }

    func play(url: URL) async throws {
        playCalls.append(url)
        isPlaying = true
        eventSink("play:\(url.path)")
        isPlaying = false
    }

    func stop() {
        stopCallCount += 1
        isPlaying = false
    }
}

private final class FakeSleeper: Sleeper {
    private let eventSink: (String) -> Void
    private(set) var sleepCalls: [Int] = []

    init(eventSink: @escaping (String) -> Void) {
        self.eventSink = eventSink
    }

    func sleep(ms: Int) async {
        sleepCalls.append(ms)
        eventSink("sleep:\(ms)")
    }
}
