import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayViewModelTests: XCTestCase {
    func testOnTapPrayBuildsAndPlaysFullDecadeSequence() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        resolver.stub(personID: "dad", token: "apostles_creed_lead", path: "/tmp/dad_apostles_creed_lead.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.onTapPray()
        await Task.yield()

        XCTAssertTrue(fakeSequencePlayer.playCalled)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps.count, 48)

        XCTAssertEqual(
            fakeSequencePlayer.receivedSteps[0],
            .play(
                url: URL(fileURLWithPath: "/tmp/dad_apostles_creed_lead.m4a"),
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        )
        XCTAssertEqual(
            fakeSequencePlayer.receivedSteps[1],
            .pause(
                ms: 250,
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        )

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    func testCurrentPromptPublishesFromPlayerCallback() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        resolver.stub(personID: "dad", token: "apostles_creed_lead", path: "/tmp/dad_apostles_creed_lead.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.onTapPray()
        await Task.yield()

        let prompt = PrayerPrompt(title: "Your turn", text: "Hail Mary, full of grace...")
        fakeSequencePlayer.emitPrompt(prompt)
        await Task.yield()
        XCTAssertEqual(viewModel.currentPrompt, prompt)

        fakeSequencePlayer.emitPrompt(nil)
        await Task.yield()
        XCTAssertNil(viewModel.currentPrompt)

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    #if DEBUG
    func testDebugTextPublishesFromPlayerDebugCallback() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        resolver.stub(personID: "dad", token: "apostles_creed_lead", path: "/tmp/dad_apostles_creed_lead.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.onTapPray()
        await Task.yield()
        XCTAssertFalse(viewModel.debugText.isEmpty)

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }
    #endif

    func testInteractiveModeDeniedMicrophoneSetsAlertAndDoesNotPlay() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer()
        let resolver = FakeAudioFileResolver()
        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: DeniedMicrophonePermissionClient()
        )
        viewModel.isInteractive = true

        viewModel.onTapPray()
        await Task.yield()
        await Task.yield()

        XCTAssertFalse(fakeSequencePlayer.playCalled)
        XCTAssertNil(viewModel.currentPrompt)
        XCTAssertTrue(viewModel.showMicrophoneDeniedAlert)
        XCTAssertEqual(viewModel.errorMessage, "Microphone access is required for Interactive mode.")
    }

    func testMissingRequiredCreedLeadSetsErrorAndDoesNotPlay() {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.onTapPray()

        XCTAssertFalse(fakeSequencePlayer.playCalled)
        XCTAssertEqual(viewModel.isPraying, false)
        XCTAssertEqual(viewModel.errorMessage, "Missing audio for apostles_creed_lead (.m4a or .wav).")
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
    private var onPromptChanged: ((PrayerPrompt?) -> Void)?

    private(set) var playCalled = false
    private(set) var receivedSteps: [PrayerSequenceStep] = []
    private(set) var stopCallCount = 0

    init(blockUntilReleased: Bool = false) {
        self.blockUntilReleased = blockUntilReleased
    }

    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void,
        onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    ) async throws {
        playCalled = true
        receivedSteps = steps
        self.onPromptChanged = onPromptChanged
        #if DEBUG
        onDebugStatusChanged?(PrayDebugStatus(stepSummary: "Step: PLAY", listenerPhase: .idle))
        #endif

        if blockUntilReleased {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func stop() {
        stopCallCount += 1
        onPromptChanged?(nil)
        releasePlay()
    }

    func emitPrompt(_ prompt: PrayerPrompt?) {
        onPromptChanged?(prompt)
    }

    func releasePlay() {
        continuation?.resume()
        continuation = nil
    }
}

private struct AlwaysGrantedMicrophonePermissionClient: MicrophonePermissionClient {
    func requestAccess() async -> Bool { true }
}

private struct DeniedMicrophonePermissionClient: MicrophonePermissionClient {
    func requestAccess() async -> Bool { false }
}
