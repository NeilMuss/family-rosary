import XCTest
@testable import family_rosary

final class SilenceTrimmerTests: XCTestCase {
    private let sampleRate = 1_000.0

    func testSilenceToneSilenceIsTrimmedWithPadding() {
        let samples = makeSegment(value: 0, ms: 200)
            + makeSegment(value: 0.05, ms: 300)
            + makeSegment(value: 0, ms: 200)
        let config = SilenceTrimConfig(threshold: 0.02, minSoundMs: 50, padMs: 120, minClipMs: 120)

        let trim = SilenceTrimmer().computeTrim(samples: samples, sampleRate: sampleRate, config: config)

        XCTAssertNotNil(trim)
        XCTAssertEqual(trim?.startSec ?? -1, 0.08, accuracy: 0.011)
        XCTAssertEqual(trim?.endSec ?? -1, 0.62, accuracy: 0.011)
    }

    func testSineWaveDetectionUsesRMSNotPerSamplePeaks() {
        let samples = makeSegment(value: 0, ms: 200)
            + makeSineWave(amplitude: 0.03, frequencyHz: 5, ms: 300)
            + makeSegment(value: 0, ms: 200)
        let config = SilenceTrimConfig(threshold: 0.02, minSoundMs: 40, padMs: 100, minClipMs: 120)

        let trim = SilenceTrimmer().computeTrim(samples: samples, sampleRate: sampleRate, config: config)

        XCTAssertNotNil(trim)
        XCTAssertGreaterThan(trim?.startSec ?? 1, 0.0)
        XCTAssertLessThan(trim?.endSec ?? 0, 0.7)
    }

    func testAllSilenceReturnsNil() {
        let samples = makeSegment(value: 0, ms: 700)

        let trim = SilenceTrimmer().computeTrim(samples: samples, sampleRate: sampleRate, config: .default)

        XCTAssertNil(trim)
    }

    func testTooShortDetectedClipReturnsNil() {
        let samples = makeSegment(value: 0, ms: 150)
            + makeSegment(value: 0.04, ms: 80)
            + makeSegment(value: 0, ms: 150)
        let config = SilenceTrimConfig(threshold: 0.02, minSoundMs: 50, padMs: 0, minClipMs: 300)

        let trim = SilenceTrimmer().computeTrim(samples: samples, sampleRate: sampleRate, config: config)

        XCTAssertNil(trim)
    }

    private func makeSegment(value: Float, ms: Int) -> [Float] {
        let count = Int(sampleRate * Double(ms) / 1000.0)
        return Array(repeating: value, count: max(0, count))
    }

    private func makeSineWave(amplitude: Float, frequencyHz: Double, ms: Int) -> [Float] {
        let count = Int(sampleRate * Double(ms) / 1000.0)
        guard count > 0 else { return [] }

        return (0..<count).map { index in
            let t = Double(index) / sampleRate
            return amplitude * Float(sin(2.0 * .pi * frequencyHz * t))
        }
    }
}
