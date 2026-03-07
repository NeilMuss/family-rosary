import AVFoundation
import Foundation

protocol MicrophoneLevelMonitoring {
    func start(onLevelChanged: @escaping (Float) -> Void) throws
    func stop()
}

final class AVAudioEngineMicrophoneLevelMonitor: MicrophoneLevelMonitoring {
    private let engine: AVAudioEngine
    private var onLevelChanged: ((Float) -> Void)?

    init(engine: AVAudioEngine = AVAudioEngine()) {
        self.engine = engine
    }

    func start(onLevelChanged: @escaping (Float) -> Void) throws {
        self.onLevelChanged = onLevelChanged

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [.defaultToSpeaker, .allowBluetoothA2DP]
        )
        try session.setActive(true)

        let inputNode = engine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        if format.channelCount == 0 {
            throw NSError(
                domain: "AVAudioEngineMicrophoneLevelMonitor",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "No microphone input channel available."]
            )
        }

        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            let level = Self.rms(of: buffer)
            self?.onLevelChanged?(level)
        }

        try engine.start()
    }

    func stop() {
        onLevelChanged = nil
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    private static func rms(of buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let channel = channelData[0]
        let frameCount = Int(buffer.frameLength)
        if frameCount == 0 { return 0 }

        var sum: Float = 0
        for idx in 0..<frameCount {
            let sample = channel[idx]
            sum += sample * sample
        }

        return sqrt(sum / Float(frameCount))
    }
}
