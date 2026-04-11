import AudioToolbox
import Foundation
import XCTest
@testable import family_rosary

final class CanonicalAudioFormatTests: XCTestCase {
    func testSpeechPresetUsesExpectedCompactVoiceSettings() {
        let format = CanonicalAudioFormat.speech

        XCTAssertEqual(format.fileExtension, "m4a")
        XCTAssertEqual(format.sampleRate, 24_000)
        XCTAssertEqual(format.channelCount, 1)
        XCTAssertEqual(format.targetBitRate, 48_000)
        XCTAssertEqual(format.maximumBypassBitRate, 64_000)
        XCTAssertEqual(format.codecFormatID, kAudioFormatMPEG4AAC)
        XCTAssertTrue(format.acceptedImportExtensions.contains("wav"))
        XCTAssertTrue(format.acceptedImportExtensions.contains("mp3"))
    }

    func testMatcherAcceptsOnlyCanonicalInspection() {
        let matcher = CanonicalAudioMatcher(format: .speech)
        let canonical = AudioAssetInspection(
            pathExtension: "m4a",
            fileSizeBytes: 4_096,
            durationSeconds: 3.2,
            sampleRate: 24_000,
            channelCount: 1,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )

        XCTAssertTrue(matcher.matches(canonical))
        XCTAssertFalse(matcher.matches(AudioAssetInspection(
            pathExtension: "wav",
            fileSizeBytes: 4_096,
            durationSeconds: 3.2,
            sampleRate: 24_000,
            channelCount: 1,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )))
        XCTAssertFalse(matcher.matches(AudioAssetInspection(
            pathExtension: "m4a",
            fileSizeBytes: 4_096,
            durationSeconds: 3.2,
            sampleRate: 44_100,
            channelCount: 1,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )))
        XCTAssertFalse(matcher.matches(AudioAssetInspection(
            pathExtension: "m4a",
            fileSizeBytes: 4_096,
            durationSeconds: 3.2,
            sampleRate: 24_000,
            channelCount: 2,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )))
    }
}

