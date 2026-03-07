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

    func test_brief_dip_during_speech_does_not_end_turn() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        _ = machine.consume(rms: UtteranceConfig.default.speechStartThreshold + 0.01, dt: 0.02)
        XCTAssertEqual(machine.state, .speaking)

        for _ in 0..<3 {
            _ = machine.consume(rms: 0.0, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .speaking)
        XCTAssertEqual(machine.silenceAccumulated, 0, accuracy: 0.0001)
    }

    func test_speech_remains_latched_with_hysteresis() {
        var machine = UtteranceDetectionStateMachine(config: .default)
        let config = UtteranceConfig.default

        _ = machine.consume(rms: config.speechStartThreshold + 0.01, dt: 0.02)
        XCTAssertTrue(machine.didStartSpeaking)
        XCTAssertEqual(machine.state, .speaking)

        // Alternate short sub-threshold dips with audible speech; this should stay latched.
        for idx in 0..<20 {
            let rms: Float = (idx % 2 == 0) ? 0.0 : config.speechContinueThreshold + 0.004
            _ = machine.consume(rms: rms, dt: 0.02)
            XCTAssertTrue(machine.didStartSpeaking)
            XCTAssertNotEqual(machine.state, .startTimedOut)
            XCTAssertNotEqual(machine.state, .completed)
        }

        XCTAssertEqual(machine.state, .speaking)
    }

    func test_completion_requires_sustained_silence() {
        var machine = UtteranceDetectionStateMachine(config: .default)
        let config = UtteranceConfig.default

        _ = machine.consume(rms: config.speechStartThreshold + 0.01, dt: 0.02)
        XCTAssertTrue(machine.didStartSpeaking)

        // 1.0s of silence after speech start is not enough (default is 1.10s).
        for _ in 0..<50 {
            _ = machine.consume(rms: 0.0, dt: 0.02)
        }
        XCTAssertNotEqual(machine.state, .completed)

        // Continue silence long enough to satisfy completion.
        for _ in 0..<20 {
            _ = machine.consume(rms: 0.0, dt: 0.02)
            if machine.state == .completed {
                break
            }
        }
        XCTAssertEqual(machine.state, .completed)
    }

    func test_speechStart_then_maxDurationExceeded_doesNotFallback() {
        let config = UtteranceConfig(
            speechStartThreshold: 0.015,
            speechContinueThreshold: 0.00825,
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

    func test_fallback_still_only_applies_before_speech_start() {
        let config = UtteranceConfig.default
        var machine = UtteranceDetectionStateMachine(config: config)

        _ = machine.consume(rms: config.speechStartThreshold + 0.01, dt: 0.02)
        XCTAssertTrue(machine.didStartSpeaking)

        for _ in 0..<600 {
            _ = machine.consume(rms: 0.0, dt: 0.02)
            if machine.state == .completed || machine.state == .maxDurationExceeded {
                break
            }
        }

        XCTAssertNotEqual(machine.state, .startTimedOut)
    }
}
