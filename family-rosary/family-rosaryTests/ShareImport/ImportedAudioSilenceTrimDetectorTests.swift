import XCTest
@testable import family_rosary

final class ImportedAudioSilenceTrimDetectorTests: XCTestCase {
    private let detector = ImportedAudioSilenceTrimDetector()

    func testLeadingSilenceSuggestsTrimmedStart() {
        let suggestion = detector.makeSuggestion(
            from: amplitudes(
                silenceFrames: 45,
                activeFrames: 180,
                tailSilenceFrames: 30,
                activeAmplitude: 0.5
            ),
            duration: 3
        )

        XCTAssertFalse(suggestion.detectionFailed)
        XCTAssertGreaterThan(suggestion.startTime, 0.2)
        XCTAssertLessThan(suggestion.startTime, 0.6)
        XCTAssertEqual(suggestion.endTime, 3, accuracy: 0.05)
    }

    func testTrailingSilenceSuggestsTrimmedEnd() {
        let suggestion = detector.makeSuggestion(
            from: amplitudes(
                silenceFrames: 0,
                activeFrames: 180,
                tailSilenceFrames: 60,
                activeAmplitude: 0.5
            ),
            duration: 3
        )

        XCTAssertFalse(suggestion.detectionFailed)
        XCTAssertEqual(suggestion.startTime, 0, accuracy: 0.05)
        XCTAssertLessThan(suggestion.endTime, 2.6)
        XCTAssertGreaterThan(suggestion.endTime, 2.0)
    }

    func testNoSilenceKeepsFullDuration() {
        let suggestion = detector.makeSuggestion(
            from: Array(repeating: 0.35, count: 300),
            duration: 3
        )

        XCTAssertFalse(suggestion.detectionFailed)
        XCTAssertEqual(suggestion.startTime, 0, accuracy: 0.02)
        XCTAssertEqual(suggestion.endTime, 3, accuracy: 0.02)
        XCTAssertGreaterThan(suggestion.confidence, 0.5)
    }

    func testVeryQuietAudioFallsBackWhenNoRegionExceedsAbsoluteMinimum() {
        let suggestion = detector.makeSuggestion(
            from: Array(repeating: 0.001, count: 300),
            duration: 3
        )

        XCTAssertTrue(suggestion.detectionFailed)
        XCTAssertEqual(suggestion.startTime, 0, accuracy: 0.001)
        XCTAssertEqual(suggestion.endTime, 3, accuracy: 0.001)
        XCTAssertEqual(suggestion.confidence, 0, accuracy: 0.001)
    }

    func testShortClipsSkipDetection() {
        let suggestion = detector.makeSuggestion(
            from: Array(repeating: 0.5, count: 150),
            duration: 1.5
        )

        XCTAssertFalse(suggestion.detectionFailed)
        XCTAssertEqual(suggestion.startTime, 0, accuracy: 0.001)
        XCTAssertEqual(suggestion.endTime, 1.5, accuracy: 0.001)
        XCTAssertEqual(suggestion.confidence, 0, accuracy: 0.001)
    }

    private func amplitudes(
        silenceFrames: Int,
        activeFrames: Int,
        tailSilenceFrames: Int,
        activeAmplitude: Double
    ) -> [Double] {
        Array(repeating: 0, count: silenceFrames)
        + Array(repeating: activeAmplitude, count: activeFrames)
        + Array(repeating: 0, count: tailSilenceFrames)
    }
}
