import AVFoundation
import XCTest
@testable import family_rosary

final class TrimmedAudioExportTests: XCTestCase {
    func testMakeTrimmedAudioFadeOutConfigurationUsesTwentyMillisecondsAtOutputEnd() {
        guard let configuration = makeTrimmedAudioFadeOutConfiguration(trimmedDuration: 3.5) else {
            return XCTFail("Expected fade-out configuration")
        }

        XCTAssertEqual(configuration.durationMs, 20)
        XCTAssertEqual(configuration.startTime.seconds, 3.48, accuracy: 0.001)
        XCTAssertEqual(configuration.endTime.seconds, 3.5, accuracy: 0.001)
    }

    func testMakeTrimmedAudioFadeOutConfigurationClampsToShortTrimmedClip() {
        guard let configuration = makeTrimmedAudioFadeOutConfiguration(trimmedDuration: 0.01) else {
            return XCTFail("Expected fade-out configuration")
        }

        XCTAssertEqual(configuration.startTime.seconds, 0, accuracy: 0.001)
        XCTAssertEqual(configuration.endTime.seconds, 0.01, accuracy: 0.001)
    }
}
