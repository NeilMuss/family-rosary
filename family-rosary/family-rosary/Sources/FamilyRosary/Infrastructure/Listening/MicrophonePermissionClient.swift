import AVFoundation
import Foundation

protocol MicrophonePermissionClient {
    func requestAccess() async -> Bool
}

struct AVAudioSessionMicrophonePermissionClient: MicrophonePermissionClient {
    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
