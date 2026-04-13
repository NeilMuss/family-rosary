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

func exportTrimmedAudio(
    sourceURL: URL,
    start: TimeInterval,
    end: TimeInterval
) async throws -> URL {
    guard end > start else {
        throw TrimmedAudioExportError.invalidTimeRange
    }

    let asset = AVURLAsset(url: sourceURL)
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
    exportSession.timeRange = CMTimeRange(
        start: CMTime(seconds: start, preferredTimescale: 600),
        duration: CMTime(seconds: end - start, preferredTimescale: 600)
    )
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
