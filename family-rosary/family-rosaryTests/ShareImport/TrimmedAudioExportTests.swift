import AVFoundation
import XCTest
@testable import family_rosary

final class TrimmedAudioExportTests: XCTestCase {
    func testMakeTrimmedAudioFadeOutConfigurationUsesTwentyMillisecondsAtOutputEnd() {
        let configuration = makeTrimmedAudioFadeOutConfiguration(trimmedDuration: 3.5)

        XCTAssertEqual(configuration?.durationMs, 20)
        XCTAssertEqual(configuration?.startTime.seconds, 3.48, accuracy: 0.001)
        XCTAssertEqual(configuration?.endTime.seconds, 3.5, accuracy: 0.001)
    }

    func testMakeTrimmedAudioFadeOutConfigurationClampsToShortTrimmedClip() {
        let configuration = makeTrimmedAudioFadeOutConfiguration(trimmedDuration: 0.01)

        XCTAssertEqual(configuration?.startTime.seconds, 0, accuracy: 0.001)
        XCTAssertEqual(configuration?.endTime.seconds, 0.01, accuracy: 0.001)
    }
}
