import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayerSequencePlayerTrimTests: XCTestCase {
    func testPlayStepTriggersTrimPrefetcher() async throws {
        let playback = PlaybackSpy()
        var prefetched: [URL] = []
        var trimDebugLines: [String] = []

        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            trimPrefetcher: { url, onLog in
                prefetched.append(url)
                onLog("TRIM \(url.lastPathComponent) -> none")
            }
        )

        let a = URL(fileURLWithPath: "/tmp/a.m4a")
        let b = URL(fileURLWithPath: "/tmp/b.m4a")

        try await player.play(
            steps: [
                .play(url: a, prompt: nil),
                .pause(ms: 10, prompt: nil),
                .play(url: b, prompt: nil)
            ],
            onPromptChanged: { _ in },
            onDebugStatusChanged: { status in
                if status.stepSummary.starts(with: "TRIM ") {
                    trimDebugLines.append(status.stepSummary)
                }
            }
        )

        XCTAssertEqual(prefetched, [a, b])
        XCTAssertEqual(playback.playCalls, [a, b])
        XCTAssertEqual(trimDebugLines, ["TRIM a.m4a -> none", "TRIM b.m4a -> none"])
    }

    func testUsesCachedTrimSegmentWhenAvailable() async throws {
        let playback = PlaybackSpy()
        let url = URL(fileURLWithPath: "/tmp/creed.m4a")
        var segmentDebugLines: [String] = []
        let expected = TrimRange(startSec: 1.1, endSec: 3.4)

        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            trimPrefetcher: nil,
            cachedTrimLookup: { requested in
                if requested == url { return .some(expected) }
                return nil
            }
        )

        try await player.play(
            steps: [.play(url: url, prompt: nil)],
            onPromptChanged: { _ in },
            onDebugStatusChanged: { status in
                if status.stepSummary.starts(with: "PLAYSEG ") {
                    segmentDebugLines.append(status.stepSummary)
                }
            }
        )

        XCTAssertEqual(playback.segmentCalls[url], expected)
        XCTAssertEqual(segmentDebugLines, ["PLAYSEG creed.m4a start=1.10 end=3.40"])
    }

    func testFallsBackToFullPlaybackWhenTrimNotReady() async throws {
        let playback = PlaybackSpy()
        let url = URL(fileURLWithPath: "/tmp/notready.m4a")
        var segmentDebugLines: [String] = []

        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            trimPrefetcher: nil,
            cachedTrimLookup: { _ in nil }
        )

        try await player.play(
            steps: [.play(url: url, prompt: nil)],
            onPromptChanged: { _ in },
            onDebugStatusChanged: { status in
                if status.stepSummary.starts(with: "PLAYSEG ") {
                    segmentDebugLines.append(status.stepSummary)
                }
            }
        )

        XCTAssertEqual(playback.segmentCalls[url], nil)
        XCTAssertEqual(segmentDebugLines, ["PLAYSEG notready.m4a full (trim not ready)"])
    }

    func testFallsBackToFullPlaybackForSuspiciousShortSegment() async throws {
        let playback = PlaybackSpy()
        let url = URL(fileURLWithPath: "/tmp/short.m4a")
        var segmentDebugLines: [String] = []

        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            trimPrefetcher: nil,
            cachedTrimLookup: { _ in .some(TrimRange(startSec: 2.0, endSec: 2.1)) }
        )

        try await player.play(
            steps: [.play(url: url, prompt: nil)],
            onPromptChanged: { _ in },
            onDebugStatusChanged: { status in
                if status.stepSummary.starts(with: "PLAYSEG ") {
                    segmentDebugLines.append(status.stepSummary)
                }
            }
        )

        XCTAssertEqual(playback.segmentCalls[url], nil)
        XCTAssertEqual(segmentDebugLines, ["PLAYSEG short.m4a full (segment invalid)"])
    }
}

private final class PlaybackSpy: AudioPlaybackClient {
    private(set) var playCalls: [URL] = []
    private(set) var segmentCalls: [URL: TrimRange] = [:]
    private(set) var isPlaying = false

    func play(url: URL) async throws {
        playCalls.append(url)
    }

    func play(url: URL, segment: TrimRange?) async throws {
        playCalls.append(url)
        if let segment {
            segmentCalls[url] = segment
        }
    }

    func stop() {
        isPlaying = false
    }
}
