import Foundation
import Combine

@MainActor
final class RecordPrayerViewModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case recording
        case review(fileURL: URL)

        static func == (lhs: Phase, rhs: Phase) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.recording, .recording):
                return true
            case let (.review(lhsURL), .review(rhsURL)):
                return lhsURL == rhsURL
            default:
                return false
            }
        }
    }

    let personID: String
    let part: AudioRecordingPart
    let promptText: String

    @Published var phase: Phase = .idle
    @Published var errorMessage: String?

    private let recorder: AudioRecorderClient
    private let onDone: () -> Void
    private let baseDirURL: () -> URL

    init(
        personID: String,
        part: AudioRecordingPart,
        promptText: String,
        recorder: AudioRecorderClient,
        baseDirURL: @escaping () -> URL = {
            FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                .appendingPathComponent("FamilyRosary", isDirectory: true)
        },
        onDone: @escaping () -> Void
    ) {
        self.personID = personID
        self.part = part
        self.promptText = promptText
        self.recorder = recorder
        self.baseDirURL = baseDirURL
        self.onDone = onDone
    }

    func onTapRecordOrStop() {
        errorMessage = nil

        switch phase {
        case .idle:
            do {
                recorder.stopPlayback()
                let fileURL = try FamilyRosaryPaths.fileURL(personID: personID, part: part, baseDirURL: baseDirURL())
                try recorder.startRecording(to: fileURL)
                phase = .recording
            } catch {
                errorMessage = error.localizedDescription
            }

        case .recording:
            do {
                try recorder.stopRecording()
                let fileURL = try FamilyRosaryPaths.fileURL(personID: personID, part: part, baseDirURL: baseDirURL())
                phase = .review(fileURL: fileURL)
                replay(url: fileURL)
            } catch {
                errorMessage = error.localizedDescription
            }

        case .review:
            break
        }
    }

    func onTapReplay() {
        guard case let .review(fileURL) = phase else { return }
        replay(url: fileURL)
    }

    func onTapKeep() {
        onDone()
    }

    func onTapRedo() {
        errorMessage = nil
        recorder.stopPlayback()

        guard case let .review(fileURL) = phase else {
            phase = .idle
            return
        }

        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
            phase = .idle
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replay(url: URL) {
        do {
            recorder.stopPlayback()
            try recorder.play(url: url)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
