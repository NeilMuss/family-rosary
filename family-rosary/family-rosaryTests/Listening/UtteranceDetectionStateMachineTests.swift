import XCTest
@testable import family_rosary

final class UtteranceDetectionStateMachineTests: XCTestCase {
    func test_noSpeechStart_triggersFallback() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        while machine.state == .waitingForSpeechStart {
            _ = machine.consume(rms: 0.001, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .startTimedOut)
        XCTAssertFalse(machine.didStartSpeaking)
    }

    func test_speechStart_then_completion_neverFallsBack() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        _ = machine.consume(rms: 0.03, dt: 0.02)
        XCTAssertTrue(machine.didStartSpeaking)

        while machine.state != .completed {
            _ = machine.consume(rms: 0.001, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .completed)
        XCTAssertTrue(machine.didStartSpeaking)
    }

    func test_longSpeech_waitsForCompletionSilence() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        for _ in 0..<300 {
            _ = machine.consume(rms: 0.05, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .speaking)

        for _ in 0..<35 {
            _ = machine.consume(rms: 0.001, dt: 0.02)
            if machine.state == .completed {
                break
            }
        }

        XCTAssertEqual(machine.state, .completed)
    }

    func test_speechStart_then_maxDurationExceeded_doesNotFallback() {
        let config = UtteranceConfig(
            startThreshold: 0.015,
            endThresholdMultiplier: 0.55,
            minSpeechSec: 0.1,
            completionSilenceSec: 1.0,
            startTimeoutSec: 1.0,
            maxUtteranceSec: 0.4
        )
        var machine = UtteranceDetectionStateMachine(config: config)

        _ = machine.consume(rms: 0.04, dt: 0.02)
        XCTAssertTrue(machine.didStartSpeaking)

        while machine.state != .maxDurationExceeded {
            _ = machine.consume(rms: 0.04, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .maxDurationExceeded)
        XCTAssertTrue(machine.didStartSpeaking)
    }

    func test_fallback_only_before_speech_starts() {
        let config = UtteranceConfig.default
        var machine = UtteranceDetectionStateMachine(config: config)

        _ = machine.consume(rms: config.startThreshold + 0.005, dt: 0.02)
        XCTAssertTrue(machine.didStartSpeaking)

        for _ in 0..<500 {
            _ = machine.consume(rms: 0.01, dt: 0.02)
            if machine.state == .completed || machine.state == .maxDurationExceeded {
                break
            }
        }

        XCTAssertNotEqual(machine.state, .startTimedOut)
    }
}
