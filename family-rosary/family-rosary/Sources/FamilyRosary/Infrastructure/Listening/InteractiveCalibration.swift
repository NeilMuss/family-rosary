import Foundation

struct InteractiveCalibration: Equatable {
    let noiseFloor: Float
    let speechStartThreshold: Float
    let speechContinueThreshold: Float
    let completionSilenceSec: TimeInterval
    let startTimeoutSec: TimeInterval
}

enum InteractiveCalibrationQuality: String, Equatable {
    case good
    case quiet
    case weak
}

struct InteractiveCalibrationEstimate: Equatable {
    let calibration: InteractiveCalibration?
    let quality: InteractiveCalibrationQuality
    let noiseFloor: Float
    let speechLevel: Float
}

enum InteractiveCalibrationHeuristics {
    static func utteranceConfig(
        for calibration: InteractiveCalibration?,
        defaults: UtteranceConfig = .default,
        startTimeoutSec: TimeInterval = InteractivePrayerPolicy.default.userResponseTimeoutSec
    ) -> UtteranceConfig {
        UtteranceConfig(
            speechStartThreshold: calibration?.speechStartThreshold ?? defaults.speechStartThreshold,
            speechContinueThreshold: calibration?.speechContinueThreshold ?? defaults.speechContinueThreshold,
            minSpeechSec: defaults.minSpeechSec,
            completionSilenceSec: calibration?.completionSilenceSec ?? defaults.completionSilenceSec,
            startTimeoutSec: calibration?.startTimeoutSec ?? startTimeoutSec,
            maxUtteranceSec: defaults.maxUtteranceSec
        )
    }

    static func estimate(
        levelSamples: [Float],
        sampleIntervalSec: TimeInterval,
        defaults: UtteranceConfig = .default,
        startTimeoutSec: TimeInterval = InteractivePrayerPolicy.default.userResponseTimeoutSec
    ) -> InteractiveCalibrationEstimate {
        let clampedLevels = levelSamples.map { max(0, $0) }
        let noiseFloor = percentile(0.2, in: clampedLevels) ?? 0
        let speechCandidates = clampedLevels.filter { $0 >= noiseFloor + 0.003 }
        let speechLevel = percentile(0.85, in: speechCandidates) ?? (percentile(0.9, in: clampedLevels) ?? 0)

        let hasUsableSpeech = speechCandidates.count >= 15 && speechLevel >= noiseFloor + 0.006
        guard hasUsableSpeech else {
            return InteractiveCalibrationEstimate(
                calibration: nil,
                quality: .weak,
                noiseFloor: noiseFloor,
                speechLevel: speechLevel
            )
        }

        let startLowerBound = noiseFloor + 0.004
        let startUpperBound = max(startLowerBound + 0.001, speechLevel * 0.9)
        let startTarget = noiseFloor + (speechLevel - noiseFloor) * 0.35
        let startThreshold = clamp(startTarget, min: startLowerBound, max: startUpperBound)

        let continueLowerBound = noiseFloor + 0.002
        let continueTarget = min(startThreshold * 0.75, startThreshold - 0.002)
        let continueThreshold = clamp(
            continueTarget,
            min: min(continueLowerBound, startThreshold),
            max: startThreshold - 0.0005
        )

        let pauseDurations = pauseRuns(
            levels: clampedLevels,
            threshold: continueThreshold,
            sampleIntervalSec: sampleIntervalSec
        )
        let completionFromPauses = (percentile(0.8, in: pauseDurations) ?? defaults.completionSilenceSec) * 1.15
        let completionSilenceSec = clamp(completionFromPauses, min: 0.9, max: 1.6)

        let quality: InteractiveCalibrationQuality = (speechLevel >= noiseFloor + 0.02) ? .good : .quiet
        let calibration = InteractiveCalibration(
            noiseFloor: noiseFloor,
            speechStartThreshold: startThreshold,
            speechContinueThreshold: continueThreshold,
            completionSilenceSec: completionSilenceSec,
            startTimeoutSec: startTimeoutSec
        )
        return InteractiveCalibrationEstimate(
            calibration: calibration,
            quality: quality,
            noiseFloor: noiseFloor,
            speechLevel: speechLevel
        )
    }

    private static func pauseRuns(
        levels: [Float],
        threshold: Float,
        sampleIntervalSec: TimeInterval
    ) -> [Double] {
        guard !levels.isEmpty else { return [] }
        var runs: [Double] = []
        var runCount = 0

        for level in levels {
            if level < threshold {
                runCount += 1
                continue
            }

            if runCount > 0 {
                let duration = Double(runCount) * sampleIntervalSec
                if duration >= 0.08 && duration <= 2.2 {
                    runs.append(duration)
                }
                runCount = 0
            }
        }

        if runCount > 0 {
            let duration = Double(runCount) * sampleIntervalSec
            if duration >= 0.08 && duration <= 2.2 {
                runs.append(duration)
            }
        }

        return runs
    }

    private static func percentile<T: BinaryFloatingPoint>(_ p: T, in values: [T]) -> T? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let ratio = max(0, min(1, p))
        let index = Int(Double(sorted.count - 1) * Double(ratio))
        return sorted[index]
    }

    private static func clamp<T: Comparable>(_ value: T, min minValue: T, max maxValue: T) -> T {
        if value < minValue { return minValue }
        if value > maxValue { return maxValue }
        return value
    }
}
