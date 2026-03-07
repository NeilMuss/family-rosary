import XCTest
@testable import family_rosary

final class InteractiveCalibrationHeuristicsTests: XCTestCase {
    func test_calibration_derives_thresholds_above_noise_floor() {
        let samples = makeSamples(noise: 0.002, speech: 0.035, speechCount: 140, noiseCount: 80)
        let estimate = InteractiveCalibrationHeuristics.estimate(
            levelSamples: samples,
            sampleIntervalSec: 0.02
        )

        guard let calibration = estimate.calibration else {
            return XCTFail("Expected usable calibration")
        }
        XCTAssertGreaterThan(calibration.speechStartThreshold, calibration.noiseFloor)
        XCTAssertLessThan(calibration.speechStartThreshold, estimate.speechLevel)
    }

    func test_continue_threshold_is_lower_than_start_threshold() {
        let samples = makeSamples(noise: 0.003, speech: 0.03, speechCount: 120, noiseCount: 100)
        let estimate = InteractiveCalibrationHeuristics.estimate(
            levelSamples: samples,
            sampleIntervalSec: 0.02
        )

        guard let calibration = estimate.calibration else {
            return XCTFail("Expected usable calibration")
        }
        XCTAssertLessThan(calibration.speechContinueThreshold, calibration.speechStartThreshold)
    }

    func test_completion_silence_is_clamped_to_forgiving_range() {
        var samples: [Float] = []
        samples.append(contentsOf: Array(repeating: 0.035, count: 100))
        samples.append(contentsOf: Array(repeating: 0.0, count: 100))
        samples.append(contentsOf: Array(repeating: 0.033, count: 80))
        samples.append(contentsOf: Array(repeating: 0.0, count: 100))

        let estimate = InteractiveCalibrationHeuristics.estimate(
            levelSamples: samples,
            sampleIntervalSec: 0.02
        )

        guard let calibration = estimate.calibration else {
            return XCTFail("Expected usable calibration")
        }
        XCTAssertGreaterThanOrEqual(calibration.completionSilenceSec, 0.9)
        XCTAssertLessThanOrEqual(calibration.completionSilenceSec, 1.6)
    }

    func test_weak_calibration_falls_back_to_defaults() {
        let weakSamples = Array(repeating: Float(0.0015), count: 150)
        let estimate = InteractiveCalibrationHeuristics.estimate(
            levelSamples: weakSamples,
            sampleIntervalSec: 0.02
        )
        XCTAssertNil(estimate.calibration)
        XCTAssertEqual(estimate.quality, .weak)

        let config = InteractiveCalibrationHeuristics.utteranceConfig(
            for: estimate.calibration,
            startTimeoutSec: 4.25
        )
        XCTAssertEqual(config.speechStartThreshold, UtteranceConfig.default.speechStartThreshold)
        XCTAssertEqual(config.speechContinueThreshold, UtteranceConfig.default.speechContinueThreshold)
        XCTAssertEqual(config.completionSilenceSec, UtteranceConfig.default.completionSilenceSec)
        XCTAssertEqual(config.startTimeoutSec, 4.25)
    }

    private func makeSamples(
        noise: Float,
        speech: Float,
        speechCount: Int,
        noiseCount: Int
    ) -> [Float] {
        var samples: [Float] = []
        samples.append(contentsOf: Array(repeating: noise, count: noiseCount / 2))
        samples.append(contentsOf: Array(repeating: speech, count: speechCount))
        samples.append(contentsOf: Array(repeating: noise, count: noiseCount / 2))
        return samples
    }
}
