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

        try await player.play(
            steps: [
                .play(
                    url: URL(fileURLWithPath: "/tmp/lead.m4a"),
                    prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
                ),
                .waitForUtterance(
                    .default,
                    prompt: PrayerPrompt(title: "Your turn", text: "I believe in God, the Father almighty...")
                ),
                .play(
                    url: URL(fileURLWithPath: "/tmp/response.m4a"),
                    prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
                )
            ],
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

        try await player.play(
            steps: [
                .play(url: URL(fileURLWithPath: "/tmp/lead.m4a"), prompt: listenPrompt),
                .waitForUtterance(.default, prompt: yourTurnPrompt),
                .play(url: URL(fileURLWithPath: "/tmp/response.m4a"), prompt: listenPrompt)
            ],
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
        try await player.play(
            steps: [
                .play(url: URL(fileURLWithPath: "/tmp/lead.m4a"), prompt: nil),
                .waitForUtterance(.default, prompt: nil),
                .pause(ms: 10, prompt: nil)
            ],
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
                steps.append(.play(url: URL(fileURLWithPath: "/tmp/recorded.m4a"), prompt: prompt))
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
}

private final class InteractivePlaybackSpy: AudioPlaybackClient {
    private(set) var events: [String] = []
    private(set) var isPlaying = false

    func play(url: URL) async throws {
        isPlaying = true
        events.append("play:\(url.path)")
        isPlaying = false
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
