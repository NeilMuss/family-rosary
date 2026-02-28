import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayViewModelTests: XCTestCase {
    func testCreedLeadAndResponsePreferredWhenBothPresent() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        resolver.stub(personID: "dad", token: "apostles_creed_lead", path: "/tmp/dad_apostles_creed_lead.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed", path: "/tmp/dad_apostles_creed.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")

        let viewModel = PrayViewModel(personID: "dad", sequencePlayer: fakeSequencePlayer, resolver: resolver)

        viewModel.onTapPray()
        await Task.yield()

        XCTAssertTrue(fakeSequencePlayer.playCalled)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps.count, 6)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps[0].url.path, "/tmp/dad_apostles_creed_lead.m4a")
        XCTAssertEqual(fakeSequencePlayer.receivedSteps[0].pauseAfterMs, 250)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps[1].url.path, "/tmp/dad_apostles_creed_response.m4a")
        XCTAssertEqual(fakeSequencePlayer.receivedSteps[1].pauseAfterMs, 400)

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    func testSingleCreedUsedAsFallback() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        resolver.stub(personID: "dad", token: "apostles_creed", path: "/tmp/dad_apostles_creed.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")

        let viewModel = PrayViewModel(personID: "dad", sequencePlayer: fakeSequencePlayer, resolver: resolver)

        viewModel.onTapPray()
        await Task.yield()

        XCTAssertTrue(fakeSequencePlayer.playCalled)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps.count, 5)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps[0].url.path, "/tmp/dad_apostles_creed.m4a")
        XCTAssertEqual(fakeSequencePlayer.receivedSteps[0].pauseAfterMs, 400)

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    func testMissingAllCreedVariantsSetsErrorAndDoesNotPlay() {
        let fakeSequencePlayer = FakePrayerSequencePlayer()
        let resolver = FakeAudioFileResolver()
        let viewModel = PrayViewModel(personID: "dad", sequencePlayer: fakeSequencePlayer, resolver: resolver)

        viewModel.onTapPray()

        XCTAssertFalse(fakeSequencePlayer.playCalled)
        XCTAssertEqual(viewModel.isPraying, false)
        XCTAssertEqual(viewModel.errorMessage, "Missing Apostles' Creed audio (lead+response or single).")
    }
}

private final class FakeAudioFileResolver: AudioFileResolving {
    private var urls: [String: URL] = [:]

    func stub(personID: String, token: String, path: String) {
        urls["\(personID)|\(token)"] = URL(fileURLWithPath: path)
    }

    func resolve(personID: String, token: String) -> URL? {
        urls["\(personID)|\(token)"]
    }
}

private final class FakePrayerSequencePlayer: PrayerSequencePlaying {
    private let blockUntilReleased: Bool
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var playCalled = false
    private(set) var receivedSteps: [PrayerPlaybackStep] = []
    private(set) var stopCallCount = 0

    init(blockUntilReleased: Bool = false) {
        self.blockUntilReleased = blockUntilReleased
    }

    func play(steps: [PrayerPlaybackStep]) async throws {
        playCalled = true
        receivedSteps = steps

        if blockUntilReleased {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func stop() {
        stopCallCount += 1
        releasePlay()
    }

    func releasePlay() {
        continuation?.resume()
        continuation = nil
    }
}
