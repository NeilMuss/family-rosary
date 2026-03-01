import AVFoundation
import Foundation

final class AVAudioPlaybackClient: NSObject, AudioPlaybackClient {
    private enum SegmentFade {
        static let minimumSegmentSec: Double = 0.2
        static let fadeInMs: Int = 10
        static let fadeOutMs: Int = 15
        static let fadeSteps: Int = 10
    }

    private let sleeper: Sleeper
    private var player: AVAudioPlayer?
    private var continuation: CheckedContinuation<Void, Error>?
    private var segmentStopTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?

    init(sleeper: Sleeper = RealSleeper()) {
        self.sleeper = sleeper
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func play(url: URL) async throws {
        try await play(url: url, segment: nil)
    }

    func play(url: URL, segment: TrimRange?) async throws {
        stop()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let player = try AVAudioPlayer(contentsOf: url)
        player.delegate = self
        player.prepareToPlay()
        self.player = player

        let effectiveSegment = normalizedSegment(segment, duration: player.duration)
        if let effectiveSegment {
            player.currentTime = effectiveSegment.startSec
            player.volume = 0
        } else {
            player.volume = 1
        }

        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            guard player.play() else {
                self.finish(
                    error: NSError(
                        domain: "AVAudioPlaybackClient",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"]
                    )
                )
                return
            }

            if let effectiveSegment {
                self.fadeTask = Task { [weak self] in
                    await self?.rampVolume(from: 0, to: 1, durationMs: SegmentFade.fadeInMs)
                }
                self.segmentStopTask = Task { [weak self] in
                    await self?.runSegmentStop(for: effectiveSegment)
                }
            }
        }
    }

    func stop() {
        player?.stop()
        finish(error: CancellationError())
    }

    private func normalizedSegment(_ segment: TrimRange?, duration: TimeInterval) -> TrimRange? {
        guard let segment else { return nil }

        let start = max(0, segment.startSec)
        let end = min(duration, segment.endSec)
        guard end > start + SegmentFade.minimumSegmentSec else { return nil }
        return TrimRange(startSec: start, endSec: end)
    }

    private func runSegmentStop(for segment: TrimRange) async {
        let segmentDurationMs = Int(((segment.endSec - segment.startSec) * 1000).rounded())
        let preFadeMs = max(0, segmentDurationMs - SegmentFade.fadeOutMs)
        await sleeper.sleep(ms: preFadeMs)

        guard player?.isPlaying == true else { return }
        await rampVolume(from: player?.volume ?? 1, to: 0, durationMs: SegmentFade.fadeOutMs)

        guard let player, player.isPlaying else { return }
        player.stop()
        finish(error: nil)
    }

    private func rampVolume(from: Float, to: Float, durationMs: Int) async {
        guard durationMs > 0 else {
            player?.volume = to
            return
        }

        let steps = max(1, SegmentFade.fadeSteps)
        let stepMs = max(1, durationMs / steps)
        for index in 1...steps {
            guard let player, player.isPlaying else { return }
            let progress = Float(index) / Float(steps)
            player.volume = from + ((to - from) * progress)
            await sleeper.sleep(ms: stepMs)
        }

        player?.volume = to
    }

    private func finish(error: Error?) {
        segmentStopTask?.cancel()
        segmentStopTask = nil
        fadeTask?.cancel()
        fadeTask = nil
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

extension AVAudioPlaybackClient: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
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
        finish(
            error: error ?? NSError(
                domain: "AVAudioPlaybackClient",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Playback decode error"]
            )
        )
    }
}
