/// Pure silence-trimming logic used to compute conservative playback segments.
import Foundation

struct SilenceTrimConfig: Equatable {
    let threshold: Float
    let minSoundMs: Int
    let padMs: Int
    let minClipMs: Int

    static let `default` = SilenceTrimConfig(
        threshold: 0.02,
        minSoundMs: 50,
        padMs: 120,
        minClipMs: 500
    )
}

struct TrimRange: Equatable {
    let startSec: Double
    let endSec: Double
}

protocol AudioSilenceTrimmer: Sendable {
    nonisolated func computeTrim(samples: [Float], sampleRate: Double, config: SilenceTrimConfig) -> TrimRange?
}

/// Finds the first/last sustained non-silent region and returns a padded segment.
struct SilenceTrimmer: AudioSilenceTrimmer {
    private let frameMs: Int = 10

    nonisolated init() {}

    nonisolated func computeTrim(samples: [Float], sampleRate: Double, config: SilenceTrimConfig) -> TrimRange? {
        guard sampleRate > 0, !samples.isEmpty else { return nil }

        let frameLength = max(1, Int(sampleRate * Double(frameMs) / 1000.0))
        let frameCount = Int(ceil(Double(samples.count) / Double(frameLength)))
        let requiredFrames = max(1, Int(ceil(Double(config.minSoundMs) / Double(frameMs))))
        let padSec = Double(max(0, config.padMs)) / 1000.0
        let minClipSec = Double(max(0, config.minClipMs)) / 1000.0
        let durationSec = Double(samples.count) / sampleRate

        let soundFrames = makeSoundFrames(
            samples: samples,
            frameLength: frameLength,
            frameCount: frameCount,
            threshold: config.threshold
        )

        guard
            let startFrame = firstSoundRunStart(soundFrames: soundFrames, requiredFrames: requiredFrames),
            let endFrame = lastSoundRunEnd(soundFrames: soundFrames, requiredFrames: requiredFrames),
            startFrame <= endFrame
        else { return nil }

        let rawStartSec = Double(startFrame * frameLength) / sampleRate
        let rawEndSec = Double((endFrame + 1) * frameLength) / sampleRate
        let startSec = max(0, rawStartSec - padSec)
        let endSec = min(durationSec, rawEndSec + padSec)

        guard startSec < endSec else { return nil }
        guard (endSec - startSec) >= minClipSec else { return nil }

        return TrimRange(startSec: startSec, endSec: endSec)
    }

    private nonisolated func makeSoundFrames(
        samples: [Float],
        frameLength: Int,
        frameCount: Int,
        threshold: Float
    ) -> [Bool] {
        var result: [Bool] = []
        result.reserveCapacity(frameCount)

        for frameIndex in 0..<frameCount {
            let start = frameIndex * frameLength
            let end = min(samples.count, start + frameLength)
            guard start < end else {
                result.append(false)
                continue
            }

            var sumSquares: Float = 0
            for sampleIndex in start..<end {
                let sample = samples[sampleIndex]
                sumSquares += sample * sample
            }
            let meanSquares = sumSquares / Float(end - start)
            let rms = sqrt(meanSquares)
            result.append(rms >= threshold)
        }

        return result
    }

    private nonisolated func firstSoundRunStart(soundFrames: [Bool], requiredFrames: Int) -> Int? {
        var runStart: Int?
        var runLength = 0

        for (index, isSound) in soundFrames.enumerated() {
            if isSound {
                if runStart == nil { runStart = index }
                runLength += 1
                if runLength >= requiredFrames { return runStart }
            } else {
                runStart = nil
                runLength = 0
            }
        }
        return nil
    }

    private nonisolated func lastSoundRunEnd(soundFrames: [Bool], requiredFrames: Int) -> Int? {
        var runEnd: Int?
        var runLength = 0

        for index in stride(from: soundFrames.count - 1, through: 0, by: -1) {
            if soundFrames[index] {
                if runEnd == nil { runEnd = index }
                runLength += 1
                if runLength >= requiredFrames { return runEnd }
            } else {
                runEnd = nil
                runLength = 0
            }
        }
        return nil
    }
}
