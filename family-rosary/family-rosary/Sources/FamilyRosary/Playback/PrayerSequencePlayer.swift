import Foundation

protocol PrayerSequencePlaying {
    func play(steps: [PrayerPlaybackStep]) async throws
    func stop()
}

final class PrayerSequencePlayer: PrayerSequencePlaying {
    private let playback: AudioPlaybackClient
    private let sleeper: Sleeper
    private var stopped = false

    init(playback: AudioPlaybackClient, sleeper: Sleeper) {
        self.playback = playback
        self.sleeper = sleeper
    }

    func play(steps: [PrayerPlaybackStep]) async throws {
        stopped = false

        for step in steps {
            if stopped { return }
            try await playback.play(url: step.url)
            if stopped { return }
            await sleeper.sleep(ms: step.pauseAfterMs)
        }
    }

    func stop() {
        stopped = true
        playback.stop()
    }
}
