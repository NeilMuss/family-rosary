import AVFoundation
import AudioToolbox
import Foundation

struct CanonicalAudioFormat: Equatable {
    let fileExtension: String
    let fileType: AVFileType
    let codecFormatID: AudioFormatID
    let sampleRate: Double
    let channelCount: Int
    let targetBitRate: Int
    let maximumBypassBitRate: Int
    let acceptedImportExtensions: Set<String>

    static let speech = CanonicalAudioFormat(
        fileExtension: "m4a",
        fileType: .m4a,
        codecFormatID: kAudioFormatMPEG4AAC,
        sampleRate: 24_000,
        channelCount: 1,
        targetBitRate: 48_000,
        maximumBypassBitRate: 64_000,
        acceptedImportExtensions: ["aac", "aif", "aiff", "caf", "m4a", "mp3", "mp4", "wav"]
    )

    // This is the app's single canonical managed-audio format.
    // It is tuned for spoken prayer content: compact AAC-in-M4A storage,
    // mono output, predictable playback, and lower on-disk size than PCM.
}

struct AudioAssetInspection: Equatable {
    let pathExtension: String
    let fileSizeBytes: Int64
    let durationSeconds: Double
    let sampleRate: Double
    let channelCount: Int
    let codecFormatID: AudioFormatID
    let estimatedBitRate: Double?
}

enum AudioAssetInspectionError: LocalizedError, Equatable {
    case unsupportedSource(extension: String)
    case sourceReadFailed
    case missingAudioTrack
    case invalidDuration
    case metadataUnavailable

    var errorDescription: String? {
        switch self {
        case let .unsupportedSource(fileExtension):
            return "Unsupported source audio format: .\(fileExtension)"
        case .sourceReadFailed:
            return "Source audio could not be read."
        case .missingAudioTrack:
            return "Source audio did not contain an audio track."
        case .invalidDuration:
            return "The audio duration could not be read."
        case .metadataUnavailable:
            return "Audio format metadata could not be read."
        }
    }
}

struct CanonicalAudioMatcher {
    let format: CanonicalAudioFormat

    init(format: CanonicalAudioFormat = .speech) {
        self.format = format
    }

    func matches(_ inspection: AudioAssetInspection) -> Bool {
        guard inspection.pathExtension == format.fileExtension else {
            return false
        }
        guard inspection.codecFormatID == format.codecFormatID else {
            return false
        }
        guard inspection.channelCount == format.channelCount else {
            return false
        }
        guard abs(inspection.sampleRate - format.sampleRate) <= 1 else {
            return false
        }
        guard inspection.fileSizeBytes > 0, inspection.durationSeconds > 0 else {
            return false
        }

        if let estimatedBitRate = inspection.estimatedBitRate {
            return estimatedBitRate <= Double(format.maximumBypassBitRate)
        }
        return true
    }
}

protocol AudioAssetInspecting {
    func inspect(url: URL) async throws -> AudioAssetInspection
}
