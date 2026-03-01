import AVFoundation
import Foundation

final class AVAudioFileSampleProvider: AudioSampleProvider, @unchecked Sendable {
    nonisolated init(scanStride: Int = 1) {
        _ = scanStride // Downsampling is intentionally disabled for trim correctness.
    }

    nonisolated func loadMonoSamples(from url: URL) throws -> (samples: [Float], sampleRate: Double) {
        let file = try AVAudioFile(forReading: url)
        let inputFormat = file.processingFormat
        let channelCount = Int(inputFormat.channelCount)

        guard channelCount > 0 else {
            throw providerError(
                message: "No channels in processing format",
                url: url,
                file: file,
                converterUsed: false,
                converterCreated: false
            )
        }

        let totalFrames = Int(file.length)
        guard totalFrames > 0 else {
            throw providerError(
                message: "Audio file has zero frames",
                url: url,
                file: file,
                converterUsed: false,
                converterCreated: false
            )
        }

        let sampleRate = inputFormat.sampleRate
        guard sampleRate > 0 else {
            throw providerError(
                message: "Invalid sample rate in processing format",
                url: url,
                file: file,
                converterUsed: false,
                converterCreated: false
            )
        }

        let chunkFrames: AVAudioFrameCount = 4096
        guard let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: chunkFrames) else {
            throw providerError(
                message: "Failed to allocate input PCM buffer",
                url: url,
                file: file,
                converterUsed: false,
                converterCreated: false
            )
        }

        let needsConversion = inputFormat.commonFormat != .pcmFormatFloat32 || inputFormat.isInterleaved
        var converter: AVAudioConverter?
        var floatFormat: AVAudioFormat = inputFormat

        if needsConversion {
            guard let target = AVAudioFormat(
                commonFormat: .pcmFormatFloat32,
                sampleRate: sampleRate,
                channels: inputFormat.channelCount,
                interleaved: false
            ) else {
                throw providerError(
                    message: "Failed to create float32 output format",
                    url: url,
                    file: file,
                    converterUsed: true,
                    converterCreated: false
                )
            }

            floatFormat = target
            converter = AVAudioConverter(from: inputFormat, to: target)
            if converter == nil {
                throw providerError(
                    message: "Failed to create AVAudioConverter",
                    url: url,
                    file: file,
                    converterUsed: true,
                    converterCreated: false
                )
            }
        }

        let expectedSamples = max(1, totalFrames)
        var output: [Float] = []
        output.reserveCapacity(expectedSamples)

        var didReadAnyFrame = false
        while file.framePosition < file.length {
            let remaining = AVAudioFrameCount(file.length - file.framePosition)
            let frameCount = min(chunkFrames, remaining)

            try file.read(into: inputBuffer, frameCount: frameCount)
            let readFrames = Int(inputBuffer.frameLength)
            if readFrames == 0 { break }
            didReadAnyFrame = true

            if needsConversion {
                guard let converter else {
                    throw providerError(
                        message: "Converter missing unexpectedly",
                        url: url,
                        file: file,
                        converterUsed: true,
                        converterCreated: false
                    )
                }

                let converted = try convertToFloat(
                    inputBuffer: inputBuffer,
                    converter: converter,
                    outputFormat: floatFormat
                )
                appendMonoSamples(from: converted, to: &output)
            } else {
                appendMonoSamples(from: inputBuffer, to: &output)
            }
        }

        if !didReadAnyFrame || output.isEmpty {
            throw providerError(
                message: "Decoded output was empty",
                url: url,
                file: file,
                converterUsed: needsConversion,
                converterCreated: converter != nil
            )
        }

        return (samples: output, sampleRate: sampleRate)
    }

    nonisolated private func convertToFloat(
        inputBuffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) throws -> AVAudioPCMBuffer {
        let maxFrames = inputBuffer.frameLength
        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: maxFrames) else {
            throw NSError(
                domain: "AVAudioFileSampleProvider",
                code: 3001,
                userInfo: [NSLocalizedDescriptionKey: "Failed to allocate converted buffer"]
            )
        }

        var inputConsumed = false
        var conversionError: NSError?
        let status = converter.convert(to: outputBuffer, error: &conversionError) { _, outStatus in
            if inputConsumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            inputConsumed = true
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let conversionError {
            throw conversionError
        }

        switch status {
        case .haveData, .inputRanDry, .endOfStream:
            return outputBuffer
        case .error:
            throw NSError(
                domain: "AVAudioFileSampleProvider",
                code: 3002,
                userInfo: [NSLocalizedDescriptionKey: "AVAudioConverter returned .error"]
            )
        @unknown default:
            throw NSError(
                domain: "AVAudioFileSampleProvider",
                code: 3003,
                userInfo: [NSLocalizedDescriptionKey: "AVAudioConverter returned unknown status"]
            )
        }
    }

    nonisolated private func appendMonoSamples(from buffer: AVAudioPCMBuffer, to output: inout [Float]) {
        guard let channelData = buffer.floatChannelData else { return }

        let channels = Int(buffer.format.channelCount)
        let frames = Int(buffer.frameLength)
        if channels == 0 || frames == 0 { return }

        var frameIndex = 0
        while frameIndex < frames {
            var sample: Float = 0
            for channelIndex in 0..<channels {
                sample += channelData[channelIndex][frameIndex]
            }
            output.append(sample / Float(channels))
            frameIndex += 1
        }
    }

    nonisolated private func providerError(
        message: String,
        url: URL,
        file: AVAudioFile,
        converterUsed: Bool,
        converterCreated: Bool
    ) -> NSError {
        let fileFormat = file.fileFormat
        let processingFormat = file.processingFormat

        return NSError(
            domain: "AVAudioFileSampleProvider",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey: message,
                "url": url.path,
                "frames": file.length,
                "fileFormat": describe(format: fileFormat),
                "processingFormat": describe(format: processingFormat),
                "converterUsed": converterUsed,
                "converterCreated": converterCreated
            ]
        )
    }

    nonisolated private func describe(format: AVAudioFormat) -> String {
        let commonFormat: String
        switch format.commonFormat {
        case .pcmFormatFloat32:
            commonFormat = "float32"
        case .pcmFormatFloat64:
            commonFormat = "float64"
        case .pcmFormatInt16:
            commonFormat = "int16"
        case .pcmFormatInt32:
            commonFormat = "int32"
        case .otherFormat:
            commonFormat = "other"
        @unknown default:
            commonFormat = "unknown"
        }

        return String(
            format: "sr=%.2f ch=%u fmt=%@ interleaved=%@",
            format.sampleRate,
            format.channelCount,
            commonFormat,
            String(format.isInterleaved)
        )
    }
}
