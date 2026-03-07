import Foundation
import AVFoundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayerSequencePlayerInteractiveTests: XCTestCase {
    func testPlayWaitPlayRunsInExpectedOrder() async throws {
        let playback = InteractivePlaybackSpy()
        let listener = FakeUtteranceListener(eventSink: { event in
            playback.events.append(event)
        })
        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            utteranceListener: listener
        )

        let steps: [PrayerSequenceStep] = [
                .play(
                    asset: AudioAssetRef(id: "lead", url: URL(fileURLWithPath: "/tmp/lead.m4a")),
                    prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
                ),
                .waitForUtterance(
                    .default,
                    prompt: PrayerPrompt(title: "Your turn", text: "I believe in God, the Father almighty...")
                ),
                .play(
                    asset: AudioAssetRef(id: "response", url: URL(fileURLWithPath: "/tmp/response.m4a")),
                    prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
                )
            ]

        try await player.play(
            steps: steps,
            onPromptChanged: { _ in }
        )

        XCTAssertEqual(
            playback.events,
            [
                "play:/tmp/lead.m4a",
                "wait",
                "play:/tmp/response.m4a"
            ]
        )
        XCTAssertEqual(listener.waitCalls.count, 1)
    }

    func testPlayerEmitsPromptChangesInStepOrderThenClears() async throws {
        let playback = InteractivePlaybackSpy()
        let listener = FakeUtteranceListener(eventSink: { _ in })
        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            utteranceListener: listener
        )

        let listenPrompt = PrayerPrompt(title: "Listen", text: "Our Father, who art in heaven...")
        let yourTurnPrompt = PrayerPrompt(title: "Your turn", text: "Our Father, who art in heaven...")
        var prompts: [PrayerPrompt?] = []

        let steps: [PrayerSequenceStep] = [
                .play(asset: AudioAssetRef(id: "lead", url: URL(fileURLWithPath: "/tmp/lead.m4a")), prompt: listenPrompt),
                .waitForUtterance(.default, prompt: yourTurnPrompt),
                .play(asset: AudioAssetRef(id: "response", url: URL(fileURLWithPath: "/tmp/response.m4a")), prompt: listenPrompt)
            ]

        try await player.play(
            steps: steps,
            onPromptChanged: { prompts.append($0) }
        )

        XCTAssertEqual(prompts, [listenPrompt, yourTurnPrompt, listenPrompt, nil])
    }

    #if DEBUG
    func testPlayerEmitsDebugStepStatusesInOrder() async throws {
        let playback = InteractivePlaybackSpy()
        let listener = FakeUtteranceListener(eventSink: { _ in })
        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            utteranceListener: listener
        )

        var statuses: [PrayDebugStatus] = []
        let steps: [PrayerSequenceStep] = [
                .play(asset: AudioAssetRef(id: "lead", url: URL(fileURLWithPath: "/tmp/lead.m4a")), prompt: nil),
                .waitForUtterance(.default, prompt: nil),
                .pause(ms: 10, prompt: nil)
            ]

        try await player.play(
            steps: steps,
            onPromptChanged: { _ in },
            onDebugStatusChanged: { statuses.append($0) }
        )

        XCTAssertTrue(statuses.contains(PrayDebugStatus(stepSummary: "Step: PLAY", listenerPhase: .idle)))
        XCTAssertTrue(
            statuses.contains(
                PrayDebugStatus(
                    stepSummary: "Step: WAIT",
                    listenerPhase: .waitingForSpeech(
                        rms: 0,
                        startThreshold: UtteranceConfig.default.startThreshold,
                        endThreshold: UtteranceConfig.default.endThreshold
                    )
                )
            )
        )
        XCTAssertEqual(statuses.last, PrayDebugStatus(stepSummary: "Done", listenerPhase: .idle))
    }
    #endif

    func testInteractiveDecadeInvokesUtteranceListenerForEveryWaitStep() async throws {
        let playback = InteractivePlaybackSpy()
        let listener = FakeUtteranceListener(eventSink: { _ in })
        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            utteranceListener: listener
        )

        let plan = RosaryDecadePlanBuilder().build(interactive: true)
        var steps: [PrayerSequenceStep] = []
        for item in plan {
            switch item {
            case .play(_, _, let prompt):
                steps.append(.play(asset: AudioAssetRef(id: "recorded", url: URL(fileURLWithPath: "/tmp/recorded.m4a")), prompt: prompt))
            case .waitForUtterance(let config, let prompt):
                steps.append(.waitForUtterance(config, prompt: prompt))
            }
        }

        try await player.play(steps: steps, onPromptChanged: { _ in })

        XCTAssertEqual(listener.waitCalls.count, 12)
    }

    func testEnergyUtteranceListenerWiringCompiles() {
        let listener: UtteranceListener = EnergyUtteranceListener(engine: AVAudioEngine())
        XCTAssertNotNil(listener as AnyObject)
    }

    func test_user_turn_without_detected_speech_falls_back_to_seed_audio() async throws {
        let playback = InteractivePlaybackSpy()
        let listener = TimeoutUtteranceListener()
        let player = PrayerSequencePlayer(
            playback: playback,
            sleeper: ImmediateSleeper(),
            utteranceListener: listener
        )

        let fallback = AudioAssetRef(id: "seed:hail_lead", url: URL(fileURLWithPath: "/tmp/hail_lead_seed.m4a"))
        try await player.play(
            steps: [
                .waitForUtteranceOrFallback(
                    .default,
                    fallbackAsset: fallback,
                    prompt: PrayerPrompt(title: "Your turn", text: "Hail Mary, full of grace..."),
                    fallbackPrompt: PrayerPrompt(title: "Continuing for you", text: "Hail Mary, full of grace...")
                )
            ],
            onPromptChanged: { _ in }
        )

        XCTAssertEqual(playback.events, ["play:/tmp/hail_lead_seed.m4a"])
    }
}

private final class InteractivePlaybackSpy: AudioPlaybackClient {
    var events: [String] = []
    private(set) var isPlaying = false

    func play(url: URL) async throws {
        isPlaying = true
        events.append("play:\(url.path)")
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

private final class FakeUtteranceListener: UtteranceListener {
    private let eventSink: (String) -> Void
    private(set) var waitCalls: [UtteranceConfig] = []

    init(eventSink: @escaping (String) -> Void) {
        self.eventSink = eventSink
    }

    func waitForUtterance(
        config: UtteranceConfig,
        onPhaseChanged: ((UtteranceDebugPhase) -> Void)?
    ) async throws {
        waitCalls.append(config)
        onPhaseChanged?(.waitingForSpeech(rms: 0, startThreshold: config.startThreshold, endThreshold: config.endThreshold))
        eventSink("wait")
        onPhaseChanged?(.completed(reason: "hard-silence"))
    }
}

private final class TimeoutUtteranceListener: UtteranceListener {
    func waitForUtterance(
        config: UtteranceConfig,
        onPhaseChanged: ((UtteranceDebugPhase) -> Void)?
    ) async throws {
        _ = config
        onPhaseChanged?(.timedOut)
        throw UtteranceListenerError.timeout
    }
}
