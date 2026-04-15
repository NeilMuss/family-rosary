import AVFoundation
import Foundation

final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(session: AVAssetExportSession) {
        self.session = session
    }
}

enum TrimmedAudioExportError: LocalizedError {
    case invalidTimeRange
    case exportSessionUnavailable
    case exportFailed(reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidTimeRange:
            return "The selected trim range is invalid."
        case .exportSessionUnavailable:
            return "The app could not start trimming this recording."
        case .exportFailed(let reason):
            return "The app could not trim this recording. \(reason)"
        }
    }
}

struct TrimmedAudioFadeOutConfiguration: Equatable {
    let durationMs: Int
    let startTime: CMTime
    let endTime: CMTime
}

private let trimmedAudioFadeOutDurationMs = 20

func makeTrimmedAudioFadeOutConfiguration(
    trimmedDuration: TimeInterval,
    fadeOutDurationMs: Int = trimmedAudioFadeOutDurationMs
) -> TrimmedAudioFadeOutConfiguration? {
    guard trimmedDuration > 0 else { return nil }

    let fadeDurationSeconds = min(trimmedDuration, Double(fadeOutDurationMs) / 1_000)
    guard fadeDurationSeconds > 0 else { return nil }

    return TrimmedAudioFadeOutConfiguration(
        durationMs: fadeOutDurationMs,
        startTime: CMTime(seconds: trimmedDuration - fadeDurationSeconds, preferredTimescale: 600),
        endTime: CMTime(seconds: trimmedDuration, preferredTimescale: 600)
    )
}

func exportTrimmedAudio(
    sourceURL: URL,
    start: TimeInterval,
    end: TimeInterval,
    logger: SharedDiagnosticsLogger? = nil
) async throws -> URL {
    guard end > start else {
        throw TrimmedAudioExportError.invalidTimeRange
    }

    let asset = AVURLAsset(url: sourceURL)
    let audioTracks = try await asset.loadTracks(withMediaType: .audio)
    guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
        throw TrimmedAudioExportError.exportSessionUnavailable
    }

    let outputURL = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString)
        .appendingPathExtension("m4a")

    if FileManager.default.fileExists(atPath: outputURL.path) {
        try? FileManager.default.removeItem(at: outputURL)
    }

    exportSession.outputURL = outputURL
    exportSession.outputFileType = .m4a
    let trimmedDuration = end - start
    exportSession.timeRange = CMTimeRange(
        start: CMTime(seconds: start, preferredTimescale: 600),
        duration: CMTime(seconds: trimmedDuration, preferredTimescale: 600)
    )

    if let fadeOutConfiguration = makeTrimmedAudioFadeOutConfiguration(trimmedDuration: trimmedDuration),
       let audioTrack = audioTracks.first {
        logger?.log(stage: "TRIM_FADE_OUT_BEGIN", event: "INFO")
        logger?.log(stage: "TRIM_FADE_OUT_DURATION_MS", event: "INFO", detail: "value=\(fadeOutConfiguration.durationMs)")
        let parameters = AVMutableAudioMixInputParameters(track: audioTrack)
        parameters.setVolumeRamp(
            fromStartVolume: 1,
            toEndVolume: 0,
            timeRange: CMTimeRange(start: fadeOutConfiguration.startTime, end: fadeOutConfiguration.endTime)
        )
        let audioMix = AVMutableAudioMix()
        audioMix.inputParameters = [parameters]
        exportSession.audioMix = audioMix
        logger?.log(stage: "TRIM_FADE_OUT_APPLIED", event: "INFO", detail: "output=\(outputURL.lastPathComponent)")
    }

    let box = ExportSessionBox(session: exportSession)

    try await withCheckedThrowingContinuation { continuation in
        exportSession.exportAsynchronously {
            switch box.session.status {
            case .completed:
                continuation.resume(returning: ())
            case .failed:
                continuation.resume(throwing: TrimmedAudioExportError.exportFailed(reason: box.session.error?.localizedDescription ?? "unknown failure"))
            case .cancelled:
                continuation.resume(throwing: TrimmedAudioExportError.exportFailed(reason: "export was cancelled"))
            default:
                continuation.resume(throwing: TrimmedAudioExportError.exportFailed(reason: "unexpected status \(box.session.status.rawValue)"))
            }
        }
    }

    return outputURL
}
