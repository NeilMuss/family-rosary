import XCTest
@testable import family_rosary

final class UtteranceDetectionStateMachineTests: XCTestCase {
    func testContinuousSpeakingAboveEndThresholdNeverCompletes() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        for _ in 0..<300 {
            _ = machine.consume(rms: 0.05, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .speaking)
        XCTAssertEqual(machine.silenceAccumulated, 0, accuracy: 0.0001)
    }

    func testSpeakingThenSustainedBelowEndThresholdCompletes() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        for _ in 0..<35 { // 0.70s speaking
            _ = machine.consume(rms: 0.05, dt: 0.02)
        }
        for _ in 0..<55 { // 1.10s below end threshold
            _ = machine.consume(rms: 0.001, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .completed)
        XCTAssertEqual(machine.completionReason, .hardSilence)
    }

    func testDipsBelowStartButAboveEndDoNotAccumulateSilence() {
        let config = UtteranceConfig.default
        XCTAssertGreaterThan(config.startThreshold, config.endThreshold)
        var machine = UtteranceDetectionStateMachine(config: config)

        for _ in 0..<20 {
            _ = machine.consume(rms: config.startThreshold + 0.002, dt: 0.02)
        }

        for _ in 0..<60 {
            _ = machine.consume(rms: config.startThreshold * 0.6, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .speaking)
        XCTAssertEqual(machine.silenceAccumulated, 0, accuracy: 0.0001)
    }

    func testLongSpeechThenShortSilenceTriggersSoftEnd() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        for _ in 0..<110 { // 2.2s speaking
            _ = machine.consume(rms: 0.05, dt: 0.02)
        }
        for _ in 0..<20 { // 0.4s silence
            _ = machine.consume(rms: 0.001, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .completed)
        XCTAssertEqual(machine.completionReason, .softEnd)
    }

    func testShortSpeechNeedsHardSilenceRule() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        for _ in 0..<60 { // 1.2s speaking < soft min
            _ = machine.consume(rms: 0.05, dt: 0.02)
        }
        for _ in 0..<20 { // 0.4s silence not enough for hard rule 0.7s
            _ = machine.consume(rms: 0.001, dt: 0.02)
        }

        XCTAssertEqual(machine.state, .speaking)
    }

    func testRMSAroundEndThresholdResetsAndAccumulatesSilenceCorrectly() {
        let config = UtteranceConfig.default
        var machine = UtteranceDetectionStateMachine(config: config)

        for _ in 0..<40 { // start speaking
            _ = machine.consume(rms: config.startThreshold + 0.003, dt: 0.02)
        }

        // Slightly below end threshold should accumulate.
        for _ in 0..<10 {
            _ = machine.consume(rms: config.endThreshold * 0.95, dt: 0.02)
        }
        XCTAssertGreaterThan(machine.silenceAccumulated, 0)

        // Slightly above end threshold should reset.
        _ = machine.consume(rms: config.endThreshold * 1.05, dt: 0.02)
        XCTAssertEqual(machine.silenceAccumulated, 0, accuracy: 0.0001)
    }

    func testNeverCrossingStartThresholdTimesOutNotComplete() {
        var machine = UtteranceDetectionStateMachine(config: .default)

        for _ in 0..<700 {
            _ = machine.consume(rms: 0.001, dt: 0.02)
            if machine.state == .timedOut {
                break
            }
        }

        XCTAssertEqual(machine.state, .timedOut)
        XCTAssertFalse(machine.speechDetected)
    }
}
