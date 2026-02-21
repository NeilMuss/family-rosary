import AVFoundation
import Foundation

final class AVAudioRecorderClient: NSObject, AudioRecorderClient {
    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?

    var isRecording: Bool {
        recorder?.isRecording ?? false
    }

    var isPlaying: Bool {
        player?.isPlaying ?? false
    }

    func startRecording(to url: URL) throws {
        stopPlayback()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker])
        try session.setActive(true)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.prepareToRecord()
        guard recorder.record() else {
            throw NSError(domain: "AVAudioRecorderClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
        }
        self.recorder = recorder
    }

    func stopRecording() throws {
        recorder?.stop()
    }

    func play(url: URL) throws {
        stopPlayback()

        let player = try AVAudioPlayer(contentsOf: url)
        player.prepareToPlay()
        guard player.play() else {
            throw NSError(domain: "AVAudioRecorderClient", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to start playback"])
        }
        self.player = player
    }

    func stopPlayback() {
        player?.stop()
        player = nil
    }
}
