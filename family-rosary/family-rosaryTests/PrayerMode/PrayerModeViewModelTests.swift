import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayerModeViewModelTests: XCTestCase {
    func testNextPrayerSegmentRestartsPlaybackFromNextPrayer() async {
        let fakeSequencePlayer = PrayerModeFakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = PrayerModeFakeAudioFileResolver()
        seedResolver(resolver)

        let prayViewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: PrayerModeAlwaysGrantedMicrophonePermissionClient()
        )
        let viewModel = PrayerModeViewModel(
            prayViewModel: prayViewModel,
            preferencesStore: PrayerModeStubPreferencesStore(),
            prayerMode: .automatic,
            prayerStyle: .alternateIStart,
            onEndRosary: {}
        )

        viewModel.start()
        await Task.yield()
        XCTAssertEqual(fakeSequencePlayer.receivedSteps.first, .play(
            asset: AudioAssetRef(
                id: "dad:apostles_creed_lead",
                url: URL(fileURLWithPath: "/tmp/dad_apostles_creed_lead.m4a")
            ),
            prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
        ))

        viewModel.onTapNextPrayerSegment()
        await Task.yield()

        XCTAssertEqual(fakeSequencePlayer.stopCalls, 1)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps.first, .play(
            asset: AudioAssetRef(
                id: "dad:apostles_creed_response",
                url: URL(fileURLWithPath: "/tmp/dad_apostles_creed_response.m4a")
            ),
            prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
        ))

        fakeSequencePlayer.releasePlay()
    }

    func testNextPrayerSegmentEndsRosaryWhenAlreadyAtLastSegment() async {
        let fakeSequencePlayer = PrayerModeFakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = PrayerModeFakeAudioFileResolver()
        seedResolver(resolver)

        let prayViewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: PrayerModeAlwaysGrantedMicrophonePermissionClient()
        )

        var endRosaryCalls = 0
        let viewModel = PrayerModeViewModel(
            prayViewModel: prayViewModel,
            preferencesStore: PrayerModeStubPreferencesStore(),
            prayerMode: .automatic,
            prayerStyle: .alternateIStart,
            onEndRosary: { endRosaryCalls += 1 }
        )

        viewModel.start()
        await Task.yield()

        for _ in 1..<RosarySequenceBuilder.makeStandardRosary().count {
            viewModel.onTapNextPrayerSegment()
        }

        viewModel.onTapNextPrayerSegment()

        XCTAssertEqual(endRosaryCalls, 1)
    }

    func testNextPrayerSegmentUpdatesDisplayedDecadeWhenCrossingBoundary() async {
        let fakeSequencePlayer = PrayerModeFakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = PrayerModeFakeAudioFileResolver()
        seedResolver(resolver)

        let prayViewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: PrayerModeAlwaysGrantedMicrophonePermissionClient()
        )
        let viewModel = PrayerModeViewModel(
            prayViewModel: prayViewModel,
            preferencesStore: PrayerModeStubPreferencesStore(),
            prayerMode: .automatic,
            prayerStyle: .alternateIStart,
            onEndRosary: {}
        )

        viewModel.start()
        await Task.yield()

        for _ in 1..<38 {
            viewModel.onTapNextPrayerSegment()
        }

        XCTAssertEqual(viewModel.displayState.sectionTitle, "2nd Decade")
    }

    private func seedResolver(_ resolver: PrayerModeFakeAudioFileResolver) {
        resolver.stub(personID: "dad", token: "apostles_creed_lead", path: "/tmp/dad_apostles_creed_lead.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")
        resolver.stub(personID: "dad", token: "glory_be_lead", path: "/tmp/dad_glory_be_lead.m4a")
        resolver.stub(personID: "dad", token: "glory_be_response", path: "/tmp/dad_glory_be_response.m4a")
        resolver.stub(personID: "dad", token: "fatima", path: "/tmp/dad_fatima.m4a")
        resolver.stub(personID: "dad", token: "hail_holy_queen_lead", path: "/tmp/dad_hail_holy_queen_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_holy_queen_response", path: "/tmp/dad_hail_holy_queen_response.m4a")
        resolver.stub(personID: "dad", token: "hail_holy_queen_closing", path: "/tmp/dad_hail_holy_queen_closing.m4a")
    }
}

private final class PrayerModeFakeAudioFileResolver: AudioFileResolving {
    private var urls: [String: URL] = [:]

    func stub(personID: String, token: String, path: String) {
        urls["\(personID)|\(token)"] = URL(fileURLWithPath: path)
    }

    func resolve(personID: String, token: String) -> URL? {
        urls["\(personID)|\(token)"]
    }
}

private final class PrayerModeFakePrayerSequencePlayer: PrayerSequencePlaying {
    private let blockUntilReleased: Bool
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var stopCalls = 0
    private(set) var receivedSteps: [PrayerSequenceStep] = []

    init(blockUntilReleased: Bool = false) {
        self.blockUntilReleased = blockUntilReleased
    }

    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void,
        onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    ) async throws {
        _ = onPromptChanged
        _ = onDebugStatusChanged
        receivedSteps = steps

        if blockUntilReleased {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func stop() {
        stopCalls += 1
        releasePlay()
    }

    func releasePlay() {
        continuation?.resume()
        continuation = nil
    }
}

private struct PrayerModeAlwaysGrantedMicrophonePermissionClient: MicrophonePermissionClient {
    func requestAccess() async -> Bool { true }
}

private struct PrayerModeStubPreferencesStore: RosaryPreferencesStore {
    func loadLastPartnerID() -> String? { nil }
    func saveLastPartnerID(_ id: String) {}
    func loadLastPrayerStyle() -> PrayerStyle? { nil }
    func saveLastPrayerStyle(_ style: PrayerStyle) {}
    func loadLastPrayerMode() -> PrayerMode? { nil }
    func saveLastPrayerMode(_ mode: PrayerMode) {}
    func loadCandleBackgroundEnabled() -> Bool { false }
    func saveCandleBackgroundEnabled(_ enabled: Bool) {}
    func loadHasSeenOnboarding() -> Bool { false }
    func saveHasSeenOnboarding(_ hasSeen: Bool) {}
}
