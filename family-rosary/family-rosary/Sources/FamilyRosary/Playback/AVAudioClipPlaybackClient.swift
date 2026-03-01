import AVFoundation
import Foundation

final class AVAudioClipPlaybackClient: NSObject, AudioPlaybackClient {
    private let sleeper: Sleeper
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?
    private var stopTask: Task<Void, Never>?

    init(sleeper: Sleeper = RealSleeper()) {
        self.sleeper = sleeper
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func play(url: URL) async throws {
        stop()

        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard player.play() else {
                self.finish(
                    error: NSError(
                        domain: "AVAudioClipPlaybackClient",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"]
                    )
                )
                return
            }
        }
    }

    func play(url: URL, startSec: Double, endSec: Double) async throws {
        stop()

        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()

        let start = max(0, startSec)
        let end = min(player.duration, endSec)
        guard end > start else {
            try await play(url: url)
            return
        }

        player.currentTime = start
        self.player = player

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard player.play() else {
                self.finish(
                    error: NSError(
                        domain: "AVAudioClipPlaybackClient",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start clip playback"]
                    )
                )
                return
            }

            let durationMs = max(1, Int(((end - start) * 1000).rounded()))
            self.stopTask = Task { [weak self] in
                await self?.sleeper.sleep(ms: durationMs)
                guard let self, let player = self.player, player.isPlaying else { return }
                player.stop()
                self.finish(error: nil)
            }
        }
    }

    func stop() {
        player?.stop()
        finish(error: CancellationError())
    }

    private func finish(error: Error?) {
        stopTask?.cancel()
        stopTask = nil
        player = nil

        guard let continuation else { return }
        self.continuation = nil

        if let error {
            continuation.resume(throwing: error)
        } else {
            continuation.resume()
        }
    }
}

extension AVAudioClipPlaybackClient: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            finish(error: nil)
        } else {
            finish(
                error: NSError(
                    domain: "AVAudioClipPlaybackClient",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Playback finished unsuccessfully"]
                )
            )
        }
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        finish(
            error: error ?? NSError(
                domain: "AVAudioClipPlaybackClient",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "Playback decode error"]
            )
        )
    }
}
