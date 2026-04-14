import AVFoundation
import Combine
import Foundation

protocol PreviewAudioSessionControlling {
    func configureForPlayback() throws
}

protocol PreviewAudioPlaying: AnyObject {
    var delegate: AVAudioPlayerDelegate? { get set }
    var duration: TimeInterval { get }
    var currentTime: TimeInterval { get set }
    var isPlaying: Bool { get }
    @discardableResult func prepareToPlay() -> Bool
    @discardableResult func play() -> Bool
    func pause()
    func stop()
}

extension AVAudioPlayer: PreviewAudioPlaying {}

protocol PreviewAudioPlayerBuilding {
    func makePlayer(url: URL) throws -> any PreviewAudioPlaying
}

struct AVPreviewAudioSessionController: PreviewAudioSessionControlling {
    func configureForPlayback() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio)
        try session.setActive(true)
    }
}

struct AVPreviewAudioPlayerFactory: PreviewAudioPlayerBuilding {
    func makePlayer(url: URL) throws -> any PreviewAudioPlaying {
        try AVAudioPlayer(contentsOf: url)
    }
}

@MainActor
final class AudioPlayerViewModel: NSObject, ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var duration: TimeInterval = 0
    @Published private(set) var currentTime: TimeInterval = 0
    @Published private(set) var errorMessage: String?
    @Published private(set) var trimStart: TimeInterval = 0
    @Published private(set) var trimEnd: TimeInterval = 0

    private let logger: SharedDiagnosticsLogger?
    private let sessionController: PreviewAudioSessionControlling
    private let playerFactory: PreviewAudioPlayerBuilding
    private var player: (any PreviewAudioPlaying)?
    private var progressTimer: Timer?
    private var loadedURL: URL?
    private let trimStep: TimeInterval = 0.25

    init(
        logger: SharedDiagnosticsLogger? = nil,
        sessionController: PreviewAudioSessionControlling? = nil,
        playerFactory: PreviewAudioPlayerBuilding? = nil
    ) {
        self.logger = logger
        self.sessionController = sessionController ?? AVPreviewAudioSessionController()
        self.playerFactory = playerFactory ?? AVPreviewAudioPlayerFactory()
        super.init()
    }

    func load(url: URL) {
        guard loadedURL != url else { return }

        stopPlayback()
        logger?.log(stage: "PREVIEW_LOAD_BEGIN", event: "INFO")
        logger?.log(stage: "PREVIEW_SOURCE_URL", event: "INFO", detail: url.path)
        logger?.log(stage: "PREVIEW_PLAYER_CREATE_BEGIN", event: "INFO")

        do {
            let player = try playerFactory.makePlayer(url: url)
            player.delegate = self
            guard player.prepareToPlay() else {
                throw NSError(
                    domain: "AudioPlayerViewModel",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Preview player could not prepare audio playback."]
                )
            }
            self.player = player
            loadedURL = url
            duration = player.duration
            currentTime = 0
            trimStart = 0
            trimEnd = player.duration
            errorMessage = nil
            logger?.log(stage: "PREVIEW_PLAYER_CREATE_SUCCESS", event: "INFO")
            logger?.log(
                stage: "PREVIEW_DURATION",
                event: "INFO",
                detail: String(format: "duration=%.2f", player.duration)
            )
            logTrimRange()
            updatePlaybackState(isPlaying: player.isPlaying)
        } catch {
            player = nil
            loadedURL = nil
            duration = 0
            currentTime = 0
            trimStart = 0
            trimEnd = 0
            errorMessage = "The app could not prepare the preview for this recording."
            logger?.log(
                stage: "PREVIEW_PLAY_FAILED",
                event: "FAIL",
                detail: "setup_failed=\(error.localizedDescription)"
            )
            updatePlaybackState(isPlaying: false)
        }
    }

    func play() {
        logger?.log(stage: "PREVIEW_PLAY_TAP", event: "INFO")
        guard let player else {
            errorMessage = "The app could not prepare the preview for this recording."
            if loadedURL != nil {
                logger?.log(stage: "PREVIEW_PLAYER_DEALLOCATED_UNEXPECTEDLY", event: "FAIL")
            }
            logger?.log(stage: "PREVIEW_PLAY_FAILED", event: "FAIL", detail: "setup_failed=player_missing")
            return
        }
        guard player.isPlaying == false else { return }
        if player.currentTime < trimStart || player.currentTime >= trimEnd {
            player.currentTime = trimStart
        }
        logTrimRange()
        logger?.log(stage: "PREVIEW_PLAY_CALL_BEGIN", event: "INFO")
        do {
            try sessionController.configureForPlayback()
        } catch {
            errorMessage = "The app could not start preview playback: \(error.localizedDescription)"
            logger?.log(stage: "PREVIEW_PLAY_FAILED", event: "FAIL", detail: "audio_session=\(error.localizedDescription)")
            updatePlaybackState(isPlaying: false)
            return
        }
        let didStart = player.play()
        updatePlaybackState(isPlaying: player.isPlaying)
        if didStart, player.isPlaying {
            currentTime = player.currentTime
            errorMessage = nil
            startProgressTimer()
            logger?.log(stage: "PREVIEW_PLAY_STARTED", event: "INFO")
        } else {
            errorMessage = "The app could not start preview playback."
            logger?.log(
                stage: "PREVIEW_PLAY_FAILED",
                event: "FAIL",
                detail: "play_returned_false playerIsPlaying=\(player.isPlaying)"
            )
        }
    }

    func pause() {
        guard let player, player.isPlaying else { return }
        player.pause()
        updatePlaybackState(isPlaying: player.isPlaying)
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
        updatePlaybackState(isPlaying: false)
        currentTime = trimStart
        stopProgressTimer()
    }

    private func setTrimStart(_ proposedValue: TimeInterval) {
        let clamped = min(max(0, proposedValue), max(0, trimEnd - trimStep))
        trimStart = clamped
        logTrimRange()
        if currentTime < trimStart || currentTime >= trimEnd {
            stopPlayback()
        }
    }

    private func setTrimEnd(_ proposedValue: TimeInterval) {
        let clamped = max(min(duration, proposedValue), min(duration, trimStart + trimStep))
        trimEnd = clamped
        logTrimRange()
        if currentTime >= trimEnd || currentTime < trimStart {
            stopPlayback()
        }
    }

    private func logTrimRange() {
        logger?.log(
            stage: "PREVIEW_TRIM_RANGE",
            event: "INFO",
            detail: String(format: "start=%.2f end=%.2f", trimStart, trimEnd)
        )
    }

    private func startProgressTimer() {
        stopProgressTimer()
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.handleProgressTick()
            }
        }
    }

    private func handleProgressTick() {
        guard let player else { return }
        if player.currentTime >= trimEnd {
            player.pause()
            player.currentTime = trimStart
            stopProgressTimer()
            updatePlaybackState(isPlaying: false)
            currentTime = trimStart
            return
        }
        currentTime = player.currentTime
        updatePlaybackState(isPlaying: player.isPlaying)
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }

    private func updatePlaybackState(isPlaying: Bool) {
        guard self.isPlaying != isPlaying else { return }
        self.isPlaying = isPlaying
        logger?.log(
            stage: "PREVIEW_PLAYER_STATE_CHANGED",
            event: "INFO",
            detail: "isPlaying=\(isPlaying)"
        )
    }
}

extension AudioPlayerViewModel: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.updatePlaybackState(isPlaying: false)
            self.currentTime = self.trimStart
            player.currentTime = self.trimStart
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.stopProgressTimer()
            self.updatePlaybackState(isPlaying: false)
            self.currentTime = self.trimStart
            self.errorMessage = "The app could not continue preview playback."
            self.logger?.log(
                stage: "PREVIEW_PLAY_FAILED",
                event: "FAIL",
                detail: error?.localizedDescription ?? "decode error"
            )
        }
    }
}
