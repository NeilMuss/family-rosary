import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayViewModelTests: XCTestCase {
    func testOnTapPrayBuildsAndPlaysFullRosarySequence() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.onTapPray()
        await Task.yield()

        XCTAssertTrue(fakeSequencePlayer.playCalled)
        XCTAssertEqual(fakeSequencePlayer.receivedSteps.count, 278)
        XCTAssertEqual(
            fakeSequencePlayer.receivedSteps[0],
            .play(
                asset: AudioAssetRef(
                    id: "dad:apostles_creed_lead",
                    url: URL(fileURLWithPath: "/tmp/dad_apostles_creed_lead.m4a")
                ),
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        )

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    func testCurrentPromptPublishesFromPlayerCallback() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        seedResolver(resolver)

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
        XCTAssertTrue(viewModel.showMicrophoneDeniedAlert)
    }

    func test_automatic_mode_never_waits_for_user_turn() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.isInteractive = false
        viewModel.onTapPray()
        await Task.yield()

        let hasWaitStep = fakeSequencePlayer.receivedSteps.contains { step in
            switch step {
            case .waitForUtterance, .waitForUtteranceOrFallback:
                return true
            default:
                return false
            }
        }
        XCTAssertFalse(hasWaitStep)

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    func test_alternate_i_start_user_leads_apostles_creed_and_first_our_father() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient()
        )
        viewModel.isInteractive = true
        viewModel.interactiveStyle = .alternateIStart

        viewModel.onTapPray()
        await Task.yield()
        await Task.yield()

        guard fakeSequencePlayer.receivedSteps.count > 3 else {
            XCTFail("Expected multiple interactive steps")
            return
        }

        switch fakeSequencePlayer.receivedSteps[0] {
        case .waitForUtteranceOrFallback(_, _, let prompt, _):
            XCTAssertEqual(prompt?.title, "Your turn")
            XCTAssertEqual(prompt?.text, "I believe in God, the Father almighty...")
        default:
            XCTFail("Expected first step to be user turn wait")
        }

        let firstOurFatherLeadIndex = fakeSequencePlayer.receivedSteps.firstIndex { step in
            switch step {
            case .waitForUtteranceOrFallback(_, _, let prompt, _):
                return prompt?.text == "Our Father, who art in heaven..."
            default:
                return false
            }
        }
        XCTAssertNotNil(firstOurFatherLeadIndex)

        fakeSequencePlayer.releasePlay()
        await Task.yield()
    }

    func testOnTapPrayDisablesIdleTimerAndRestoresWhenPlaybackCompletes() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        let idleTimerController = FakeIdleTimerController()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient(),
            idleTimerController: idleTimerController
        )

        viewModel.onTapPray()
        await Task.yield()

        XCTAssertEqual(idleTimerController.disableCalls, 1)
        XCTAssertEqual(idleTimerController.restoreCalls, 0)

        fakeSequencePlayer.releasePlay()
        await Task.yield()

        XCTAssertEqual(idleTimerController.restoreCalls, 1)
    }

    func testOnTapStopRestoresIdleTimerDuringActivePrayerPlayback() async {
        let fakeSequencePlayer = FakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = FakeAudioFileResolver()
        let idleTimerController = FakeIdleTimerController()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: AlwaysGrantedMicrophonePermissionClient(),
            idleTimerController: idleTimerController
        )

        viewModel.onTapPray()
        await Task.yield()
        viewModel.onTapStop()
        await Task.yield()

        XCTAssertEqual(idleTimerController.disableCalls, 1)
        XCTAssertEqual(idleTimerController.restoreCalls, 1)
    }

    private func seedResolver(_ resolver: FakeAudioFileResolver) {
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

    init(blockUntilReleased: Bool = false) {
        self.blockUntilReleased = blockUntilReleased
    }

    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void,
        onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    ) async throws {
        _ = onDebugStatusChanged
        playCalled = true
        receivedSteps = steps
        self.onPromptChanged = onPromptChanged

        if blockUntilReleased {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func stop() {
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

@MainActor
private final class FakeIdleTimerController: IdleTimerControlling {
    private(set) var disableCalls = 0
    private(set) var restoreCalls = 0

    func disableIdleTimer() {
        disableCalls += 1
    }

    func restoreIdleTimer() {
        restoreCalls += 1
    }
}
