import AVFoundation
import Foundation

struct TrimSuggestion: Equatable {
    let startTime: Double
    let endTime: Double
    let confidence: Float
    let detectionFailed: Bool
}

struct ImportedAudioSilenceTrimDetector {
    struct Configuration: Equatable {
        let targetSamplesPerSecond: Double
        let movingAverageWindowSize: Int
        let consecutiveFramesRequired: Int
        let thresholdRatio: Double
        let absoluteMinimum: Double
        let startPadding: Double
        let endPadding: Double
        let minimumDurationForDetection: Double

        static let `default` = Configuration(
            targetSamplesPerSecond: 150,
            movingAverageWindowSize: 5,
            consecutiveFramesRequired: 4,
            thresholdRatio: 0.05,
            absoluteMinimum: 0.003,
            startPadding: 0.15,
            endPadding: 0.2,
            minimumDurationForDetection: 2
        )
    }

    let configuration: Configuration

    init(configuration: Configuration = .default) {
        self.configuration = configuration
    }

    func suggestTrim(for sourceURL: URL) throws -> TrimSuggestion {
        let audioFile = try AVAudioFile(forReading: sourceURL)
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        guard duration.isFinite, duration > 0 else {
            return TrimSuggestion(startTime: 0, endTime: 0, confidence: 0, detectionFailed: true)
        }

        if duration < configuration.minimumDurationForDetection {
            return TrimSuggestion(startTime: 0, endTime: duration, confidence: 0, detectionFailed: false)
        }

        let amplitudes = try makeRMSAmplitudes(from: audioFile)
        return makeSuggestion(from: amplitudes, duration: duration)
    }

    func makeSuggestion(from amplitudes: [Double], duration: Double) -> TrimSuggestion {
        guard duration.isFinite, duration > 0 else {
            return TrimSuggestion(startTime: 0, endTime: 0, confidence: 0, detectionFailed: true)
        }

        if duration < configuration.minimumDurationForDetection {
            return TrimSuggestion(startTime: 0, endTime: duration, confidence: 0, detectionFailed: false)
        }

        guard amplitudes.isEmpty == false else {
            return TrimSuggestion(startTime: 0, endTime: duration, confidence: 0, detectionFailed: true)
        }

        let smoothed = smooth(amplitudes: amplitudes, windowSize: configuration.movingAverageWindowSize)
        let maxAmplitude = smoothed.max() ?? 0
        let threshold = max(maxAmplitude * configuration.thresholdRatio, configuration.absoluteMinimum)

        guard let startIndex = firstDetectedIndex(in: smoothed, threshold: threshold),
              let endIndex = lastDetectedIndex(in: smoothed, threshold: threshold),
              endIndex >= startIndex else {
            return TrimSuggestion(startTime: 0, endTime: duration, confidence: 0, detectionFailed: true)
        }

        let secondsPerSample = duration / Double(smoothed.count)
        let detectedStart = Double(startIndex) * secondsPerSample
        let detectedEnd = Double(endIndex + 1) * secondsPerSample
        let startTime = max(0, detectedStart - configuration.startPadding)
        let endTime = min(duration, detectedEnd + configuration.endPadding)
        let confidence = makeConfidence(maxAmplitude: maxAmplitude, threshold: threshold, keptDuration: endTime - startTime, totalDuration: duration)

        return TrimSuggestion(
            startTime: startTime,
            endTime: max(startTime, endTime),
            confidence: confidence,
            detectionFailed: false
        )
    }

    private func makeRMSAmplitudes(from audioFile: AVAudioFile) throws -> [Double] {
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let channelCount = Int(format.channelCount)
        let windowFrameCount = max(1, Int((sampleRate / configuration.targetSamplesPerSecond).rounded()))
        let readFrameCount = AVAudioFrameCount(max(windowFrameCount * 8, 1024))

        var amplitudes: [Double] = []
        var accumulatedSquares = 0.0
        var accumulatedFrames = 0

        while true {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: readFrameCount) else {
                break
            }
            try audioFile.read(into: buffer)
            let frameLength = Int(buffer.frameLength)
            if frameLength == 0 {
                break
            }

            for frameIndex in 0..<frameLength {
                var frameSquareSum = 0.0
                for channelIndex in 0..<channelCount {
                    let sample = sampleValue(in: buffer, channel: channelIndex, frame: frameIndex)
                    frameSquareSum += sample * sample
                }
                accumulatedSquares += frameSquareSum / Double(channelCount)
                accumulatedFrames += 1

                if accumulatedFrames >= windowFrameCount {
                    amplitudes.append(sqrt(accumulatedSquares / Double(accumulatedFrames)))
                    accumulatedSquares = 0
                    accumulatedFrames = 0
                }
            }
        }

        if accumulatedFrames > 0 {
            amplitudes.append(sqrt(accumulatedSquares / Double(accumulatedFrames)))
        }

        return amplitudes
    }

    private func sampleValue(in buffer: AVAudioPCMBuffer, channel: Int, frame: Int) -> Double {
        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channelData = buffer.floatChannelData else { return 0 }
            return Double(channelData[channel][frame])
        case .pcmFormatInt16:
            guard let channelData = buffer.int16ChannelData else { return 0 }
            return Double(channelData[channel][frame]) / Double(Int16.max)
        case .pcmFormatInt32:
            guard let channelData = buffer.int32ChannelData else { return 0 }
            return Double(channelData[channel][frame]) / Double(Int32.max)
        default:
            return 0
        }
    }

    private func smooth(amplitudes: [Double], windowSize: Int) -> [Double] {
        guard amplitudes.isEmpty == false, windowSize > 1 else { return amplitudes }

        let radius = windowSize / 2
        return amplitudes.indices.map { index in
            let lowerBound = max(0, index - radius)
            let upperBound = min(amplitudes.count - 1, index + radius)
            let slice = amplitudes[lowerBound...upperBound]
            return slice.reduce(0, +) / Double(slice.count)
        }
    }

    private func firstDetectedIndex(in amplitudes: [Double], threshold: Double) -> Int? {
        let required = configuration.consecutiveFramesRequired
        guard amplitudes.count >= required else { return nil }

        for start in 0...(amplitudes.count - required) {
            if amplitudes[start..<(start + required)].allSatisfy({ $0 > threshold }) {
                return start
            }
        }

        return nil
    }

    private func lastDetectedIndex(in amplitudes: [Double], threshold: Double) -> Int? {
        let required = configuration.consecutiveFramesRequired
        guard amplitudes.count >= required else { return nil }

        for start in stride(from: amplitudes.count - required, through: 0, by: -1) {
            if amplitudes[start..<(start + required)].allSatisfy({ $0 > threshold }) {
                return start + required - 1
            }
        }

        return nil
    }

    private func makeConfidence(
        maxAmplitude: Double,
        threshold: Double,
        keptDuration: Double,
        totalDuration: Double
    ) -> Float {
        guard threshold > 0, totalDuration > 0, keptDuration > 0 else { return 0 }

        let signalMargin = min(1, max(0, (maxAmplitude - threshold) / max(threshold * 3, 0.0001)))
        let keptFraction = min(1, max(0, keptDuration / totalDuration))
        return Float((signalMargin * 0.7) + (keptFraction * 0.3))
    }
}
