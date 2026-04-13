import AVFoundation
import Combine
import Foundation

@MainActor
final class AudioPlayerViewModel: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var trimStart: TimeInterval = 0
    @Published private(set) var trimEnd: TimeInterval = 0

    private let logger: SharedDiagnosticsLogger?
    private var player: AVAudioPlayer?
    private var progressTimer: Timer?
    private var loadedURL: URL?
    private let trimStep: TimeInterval = 0.25

    init(logger: SharedDiagnosticsLogger? = nil) {
        self.logger = logger
        super.init()
    }

    func load(url: URL) {
        guard loadedURL != url else { return }

        stopPlayback()
        logger?.log(stage: "AUDIO_PREVIEW_LOAD_BEGIN", event: "INFO", detail: url.lastPathComponent)

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.prepareToPlay()
            self.player = player
            loadedURL = url
            duration = player.duration
            currentTime = 0
            trimStart = 0
            trimEnd = player.duration
            errorMessage = nil
            logger?.log(
                stage: "AUDIO_PREVIEW_LOAD_SUCCESS",
                event: "INFO",
                detail: String(format: "duration=%.2f", player.duration)
            )
        } catch {
            player = nil
            loadedURL = nil
            duration = 0
            currentTime = 0
            trimStart = 0
            trimEnd = 0
            errorMessage = "Unable to preview audio"
            logger?.log(
                stage: "AUDIO_PREVIEW_LOAD_FAIL",
                event: "FAIL",
                detail: error.localizedDescription
            )
        }
    }

    func play() {
        guard let player else { return }
        guard player.isPlaying == false else { return }
        if player.currentTime < trimStart || player.currentTime >= trimEnd {
            player.currentTime = trimStart
        }
        if player.play() {
            isPlaying = true
            currentTime = player.currentTime
            startProgressTimer()
            logger?.log(
                stage: "TRIM_PLAY_SEGMENT",
                event: "INFO",
                detail: String(format: "start=%.2f end=%.2f", trimStart, trimEnd)
            )
            logger?.log(stage: "AUDIO_PREVIEW_PLAY", event: "INFO")
        }
    }

    func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        isPlaying = false
        currentTime = player.currentTime
        stopProgressTimer()
        logger?.log(stage: "AUDIO_PREVIEW_PAUSE", event: "INFO")
    }

    func togglePlay() {
        isPlaying ? pause() : play()
    }

    func decrementTrimStart() {
        setTrimStart(trimStart - trimStep)
    }

    func incrementTrimStart() {
        setTrimStart(trimStart + trimStep)
    }

    func decrementTrimEnd() {
        setTrimEnd(trimEnd - trimStep)
    }

    func incrementTrimEnd() {
        setTrimEnd(trimEnd + trimStep)
    }

    func stopPlayback() {
        player?.stop()
        player?.currentTime = trimStart
        isPlaying = false
        currentTime = trimStart
        stopProgressTimer()
    }

    private func setTrimStart(_ proposedValue: TimeInterval) {
        let clamped = min(max(0, proposedValue), max(0, trimEnd - trimStep))
        trimStart = clamped
        logger?.log(
            stage: "TRIM_SET_START",
            event: "INFO",
            detail: String(format: "value=%.2f", clamped)
        )
        if currentTime < trimStart || currentTime >= trimEnd {
            stopPlayback()
        }
    }

    private func setTrimEnd(_ proposedValue: TimeInterval) {
        let clamped = max(min(duration, proposedValue), min(duration, trimStart + trimStep))
        trimEnd = clamped
        logger?.log(
            stage: "TRIM_SET_END",
            event: "INFO",
            detail: String(format: "value=%.2f", clamped)
        )
        if currentTime >= trimEnd || currentTime < trimStart {
            stopPlayback()
        }
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let player = self.player else { return }
                if player.currentTime >= self.trimEnd {
                    player.pause()
                    player.currentTime = self.trimStart
                    self.stopProgressTimer()
                    self.isPlaying = false
                    self.currentTime = self.trimStart
                    return
                }
                self.currentTime = player.currentTime
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

extension AudioPlayerViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.isPlaying = false
            self.currentTime = self.trimStart
            player.currentTime = self.trimStart
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.isPlaying = false
            self.currentTime = self.trimStart
            self.errorMessage = "Unable to preview audio"
            self.logger?.log(
                stage: "AUDIO_PREVIEW_LOAD_FAIL",
                event: "FAIL",
                detail: error?.localizedDescription ?? "decode error"
            )
        }
    }
}
