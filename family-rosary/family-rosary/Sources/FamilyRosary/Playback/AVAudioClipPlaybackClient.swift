import AVFoundation
import Foundation

final class AVAudioClipPlaybackClient: NSObject, AudioPlaybackClient {
    private let clipFadeInSec: Double = 0.015
    private let clipFadeOutSec: Double = 0.015

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

        let start = max(0, startSec)
        let end = min(player.duration, endSec)
        guard end > start else {
            try await play(url: url)
            return
        }

        let clipDurationSec = end - start
        let fades = clampedClipFades(durationSec: clipDurationSec)
        #if DEBUG
        DebugLog.shared.log(
            String(
                format: "PLAY_CLIP start=%.3f end=%.3f duration=%.3f",
                start,
                end,
                clipDurationSec
            )
        )
        DebugLog.shared.log(
            String(
                format: "PLAY_CLIP fadeIn=%.3f fadeOut=%.3f",
                fades.fadeInSec,
                fades.fadeOutSec
            )
        )
        #endif

        player.volume = 0
        player.currentTime = start
        player.prepareToPlay()
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

            player.setVolume(1.0, fadeDuration: TimeInterval(fades.fadeInSec))

            let fadeOutStartSec = max(0, clipDurationSec - fades.fadeOutSec)
            self.stopTask = Task { [weak self] in
                await self?.sleeper.sleep(ms: max(1, Int((fadeOutStartSec * 1000).rounded())))
                guard let self, let player = self.player, player.isPlaying else { return }

                if fades.fadeOutSec > 0 {
                    player.setVolume(0, fadeDuration: TimeInterval(fades.fadeOutSec))
                    await self.sleeper.sleep(ms: max(1, Int((fades.fadeOutSec * 1000).rounded())))
                }
                guard let player = self.player, player.isPlaying else { return }
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

    private func clampedClipFades(durationSec: Double) -> (fadeInSec: Double, fadeOutSec: Double) {
        let desiredIn = clipFadeInSec
        let desiredOut = clipFadeOutSec
        let desiredTotal = desiredIn + desiredOut
        guard desiredTotal > 0, durationSec > 0 else {
            return (0, 0)
        }
        if desiredTotal <= durationSec {
            return (desiredIn, desiredOut)
        }

        let scale = durationSec / desiredTotal
        return (desiredIn * scale, desiredOut * scale)
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
