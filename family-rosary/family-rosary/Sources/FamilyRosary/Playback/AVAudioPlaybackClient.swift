import AVFoundation
import Foundation

final class AVAudioPlaybackClient: NSObject, AudioPlaybackClient {
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func play(url: URL) async throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard player.play() else {
                self.player = nil
                self.continuation = nil
                continuation.resume(
                    throwing: NSError(
                        domain: "AVAudioPlaybackClient",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"]
                    )
                )
                return
            }
        }
    }

    func stop() {
        player?.stop()
        player = nil
        finish(error: CancellationError())
    }

    private func finish(error: Error?) {
        guard let continuation else { return }
        self.continuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

extension AVAudioPlaybackClient: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        if flag {
            finish(error: nil)
        } else {
            finish(
                error: NSError(
                    domain: "AVAudioPlaybackClient",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Playback finished unsuccessfully"]
                )
            )
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        self.player = nil
        finish(
            error: error ?? NSError(
                domain: "AVAudioPlaybackClient",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Playback decode error"]
            )
        )
    }
}
