import Foundation
import AVFoundation

struct SharedAudioInspection: Equatable {
    let durationSeconds: Double
}

enum SharedAudioInspectionError: LocalizedError {
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .invalidDuration:
            return "The audio duration could not be read."
        }
    }
}

protocol SharedAudioInspecting {
    func inspect(url: URL) throws -> SharedAudioInspection
}

struct AVSharedAudioInspector: SharedAudioInspecting {
    func inspect(url: URL) throws -> SharedAudioInspection {
        let player = try AVAudioPlayer(contentsOf: url)
        let duration = player.duration
        guard duration.isFinite, duration > 0 else {
            throw SharedAudioInspectionError.invalidDuration
        }
        return SharedAudioInspection(durationSeconds: duration)
    }
}
