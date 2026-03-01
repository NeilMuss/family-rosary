import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayerSequencePlayerClipTests: XCTestCase {
    func testSequencePlayerCallsPlaybackWithCorrectTimes() async throws {
        let playback = PlaybackSpy()
        let clip = PrayerClip(
            id: "dad:apostles_creed_lead",
            fileName: "dad_apostles_creed_lead.m4a",
            prayer: "apostles_creed",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 4.82,
            endSec: 28.18
        )
        let catalog = CatalogStub(clips: [clip])
        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            clipCatalog: catalog
        )

        let asset = AudioAssetRef(id: clip.id, url: URL(fileURLWithPath: "/tmp/dad_apostles_creed_lead.m4a"))
        try await player.play(
            steps: [.play(asset: asset, prompt: nil)],
            onPromptChanged: { _ in }
        )

        XCTAssertEqual(playback.segmentCalls.count, 1)
        XCTAssertEqual(playback.segmentCalls[0].url, asset.url)
        XCTAssertEqual(playback.segmentCalls[0].startSec, 4.82, accuracy: 0.001)
        XCTAssertEqual(playback.segmentCalls[0].endSec, 28.18, accuracy: 0.001)
    }
}

private struct CatalogStub: PrayerClipCatalog {
    let clips: [PrayerClip]

    func allClips() -> [PrayerClip] { clips }

    func clip(id: String) -> PrayerClip? {
        clips.first { $0.id == id }
    }
}

private final class PlaybackSpy: AudioPlaybackClient {
    struct SegmentCall {
        let url: URL
        let startSec: Double
        let endSec: Double
    }

    private(set) var segmentCalls: [SegmentCall] = []
    private(set) var isPlaying = false

    func play(url: URL) async throws {
        segmentCalls.append(.init(url: url, startSec: 0, endSec: 0))
    }

    func play(url: URL, startSec: Double, endSec: Double) async throws {
        segmentCalls.append(.init(url: url, startSec: startSec, endSec: endSec))
    }

    func stop() {
        isPlaying = false
    }
}
