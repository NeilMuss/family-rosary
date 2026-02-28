import Foundation
import Combine

@MainActor
final class PrayViewModel: ObservableObject {
    @Published var isPraying = false
    @Published var errorMessage: String?

    private let personID: String
    private let sequencePlayer: PrayerSequencePlaying
    private let resolver: AudioFileResolving
    private var playTask: Task<Void, Never>?

    init(
        personID: String = "dad",
        sequencePlayer: PrayerSequencePlaying,
        resolver: AudioFileResolving
    ) {
        self.personID = personID
        self.sequencePlayer = sequencePlayer
        self.resolver = resolver
    }

    func onTapPray() {
        guard !isPraying else { return }
        errorMessage = nil

        guard let steps = buildPrayerSteps() else { return }

        isPraying = true
        playTask?.cancel()
        playTask = Task { [weak self] in
            guard let self else { return }
            defer {
                self.isPraying = false
                self.playTask = nil
            }

            do {
                try await self.sequencePlayer.play(steps: steps)
            } catch is CancellationError {
            } catch {
                if self.errorMessage == nil || self.errorMessage?.isEmpty == true {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func onTapStop() {
        playTask?.cancel()
        sequencePlayer.stop()
        isPraying = false
    }

    private func buildPrayerSteps() -> [PrayerPlaybackStep]? {
        var steps: [PrayerPlaybackStep] = []

        let creedLead = resolver.resolve(personID: personID, token: "apostles_creed_lead")
        let creedResponse = resolver.resolve(personID: personID, token: "apostles_creed_response")
        let creedSingle = resolver.resolve(personID: personID, token: AudioRecordingPart.apostlesCreed.filenameToken)

        if let creedLead, let creedResponse {
            steps.append(PrayerPlaybackStep(url: creedLead, pauseAfterMs: 250))
            steps.append(PrayerPlaybackStep(url: creedResponse, pauseAfterMs: 400))
        } else if let creedSingle {
            steps.append(PrayerPlaybackStep(url: creedSingle, pauseAfterMs: 400))
        } else {
            errorMessage = "Missing Apostles' Creed audio (lead+response or single)."
            return nil
        }

        let orderedParts: [AudioRecordingPart] = [
            .ourFatherLead,
            .ourFatherResponse,
            .hailMaryLead,
            .hailMaryResponse
        ]
        let pauses: [Int] = [400, 400, 400, 0]

        for (index, part) in orderedParts.enumerated() {
            guard let url = resolver.resolve(personID: personID, token: part.filenameToken) else {
                errorMessage = "Missing audio for \(part.filenameToken) (.m4a or .wav)."
                return nil
            }
            steps.append(PrayerPlaybackStep(url: url, pauseAfterMs: pauses[index]))
        }

        return steps
    }
}
