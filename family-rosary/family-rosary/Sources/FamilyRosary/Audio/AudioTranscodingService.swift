@preconcurrency import AVFoundation
import AudioToolbox
import CoreMedia
import Foundation

enum AudioTranscodingError: LocalizedError, Equatable {
    case unsupportedSource(extension: String)
    case sourceReadFailed
    case exportCreationFailed
    case exportCancelled
    case exportFailed(reason: String)
    case outputMissing
    case outputInvalid(reason: String)

    var errorDescription: String? {
        switch self {
        case let .unsupportedSource(fileExtension):
            return "Source audio format .\(fileExtension) is not supported."
        case .sourceReadFailed:
            return "Source audio could not be read."
        case .exportCreationFailed:
            return "Audio conversion could not start."
        case .exportCancelled:
            return "Audio conversion was cancelled."
        case let .exportFailed(reason):
            return "Audio conversion failed: \(reason)"
        case .outputMissing:
            return "Converted audio file was missing after export."
        case let .outputInvalid(reason):
            return "Converted audio file was invalid or empty: \(reason)"
        }
    }
}

struct PreparedAudioFile: Equatable {
    enum Strategy: Equatable {
        case bypassedCanonical
        case transcoded
    }

    let fileURL: URL
    let inspection: AudioAssetInspection
    let strategy: Strategy
}

protocol AudioTranscodeExporting {
    func export(sourceURL: URL, destinationURL: URL, format: CanonicalAudioFormat) async throws
}

protocol CanonicalAudioValidating {
    func validate(url: URL) async throws -> AudioAssetInspection
}

protocol AudioTranscoding {
    func transcode(sourceURL: URL, outputURL: URL) async throws -> AudioAssetInspection
}

protocol ImportedAudioPreparing {
    func prepare(sourceURL: URL, destinationURL: URL) async throws -> PreparedAudioFile
}

protocol AudioTranscodingLogging {
    func log(event: String, metadata: [String: String])
}

struct DebugLogAudioTranscodingLogger: AudioTranscodingLogging {
    func log(event: String, metadata: [String: String]) {
        #if DEBUG
        let suffix = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " | ")
        let line = suffix.isEmpty ? event : "\(event) | \(suffix)"
        DebugLog.shared.log(line)
        #endif
    }
}

struct AVAudioAssetInspector: AudioAssetInspecting {
    let format: CanonicalAudioFormat
    let fileManager: FileManager

    init(
        format: CanonicalAudioFormat = .speech,
        fileManager: FileManager = .default
    ) {
        self.format = format
        self.fileManager = fileManager
    }

    func inspect(url: URL) async throws -> AudioAssetInspection {
        let pathExtension = url.pathExtension.lowercased()
        guard format.acceptedImportExtensions.contains(pathExtension) else {
            throw AudioAssetInspectionError.unsupportedSource(extension: pathExtension.isEmpty ? "(none)" : pathExtension)
        }

        let player: AVAudioPlayer
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw AudioAssetInspectionError.sourceReadFailed
        }

        let durationSeconds = player.duration
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            throw AudioAssetInspectionError.invalidDuration
        }

        let asset = AVURLAsset(url: url)
        let tracks: [AVAssetTrack]
        do {
            tracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw AudioAssetInspectionError.metadataUnavailable
        }
        guard let track = tracks.first else {
            throw AudioAssetInspectionError.missingAudioTrack
        }

        let formatDescriptions: [Any]
        do {
            formatDescriptions = try await track.load(.formatDescriptions)
        } catch {
            throw AudioAssetInspectionError.metadataUnavailable
        }
        guard let description = formatDescriptions.first,
              let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description as! CMAudioFormatDescription) else {
            throw AudioAssetInspectionError.metadataUnavailable
        }

        let estimatedDataRate: Float
        do {
            estimatedDataRate = try await track.load(.estimatedDataRate)
        } catch {
            throw AudioAssetInspectionError.metadataUnavailable
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSizeBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0

        return AudioAssetInspection(
            pathExtension: pathExtension,
            fileSizeBytes: fileSizeBytes,
            durationSeconds: durationSeconds,
            sampleRate: asbd.pointee.mSampleRate,
            channelCount: Int(asbd.pointee.mChannelsPerFrame),
            codecFormatID: asbd.pointee.mFormatID,
            estimatedBitRate: estimatedDataRate > 0 ? Double(estimatedDataRate) : nil
        )
    }
}

struct CanonicalAudioValidator: CanonicalAudioValidating {
    let format: CanonicalAudioFormat
    let inspector: AudioAssetInspecting
    let matcher: CanonicalAudioMatcher
    let fileManager: FileManager

    init(
        format: CanonicalAudioFormat = .speech,
        inspector: AudioAssetInspecting = AVAudioAssetInspector(),
        matcher: CanonicalAudioMatcher = CanonicalAudioMatcher(),
        fileManager: FileManager = .default
    ) {
        self.format = format
        self.inspector = inspector
        self.matcher = matcher
        self.fileManager = fileManager
    }

    func validate(url: URL) async throws -> AudioAssetInspection {
        guard fileManager.fileExists(atPath: url.path) else {
            throw AudioTranscodingError.outputMissing
        }

        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        let fileSizeBytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        guard fileSizeBytes > 0 else {
            throw AudioTranscodingError.outputInvalid(reason: "file size was 0 bytes")
        }
        guard url.pathExtension.lowercased() == format.fileExtension else {
            throw AudioTranscodingError.outputInvalid(reason: "expected .\(format.fileExtension) output")
        }

        let inspection: AudioAssetInspection
        do {
            inspection = try await inspector.inspect(url: url)
        } catch let error as AudioAssetInspectionError {
            throw AudioTranscodingError.outputInvalid(reason: error.localizedDescription)
        } catch {
            throw AudioTranscodingError.outputInvalid(reason: error.localizedDescription)
        }

        guard matcher.matches(inspection) else {
            throw AudioTranscodingError.outputInvalid(reason: "audio did not match canonical format requirements")
        }

        return inspection
    }
}

struct AudioTranscodingService: AudioTranscoding {
    let format: CanonicalAudioFormat
    let validator: CanonicalAudioValidating
    let exporter: AudioTranscodeExporting
    let inspector: AudioAssetInspecting
    let logger: AudioTranscodingLogging
    let clock: () -> Date

    init(
        format: CanonicalAudioFormat = .speech,
        validator: CanonicalAudioValidating,
        exporter: AudioTranscodeExporting,
        inspector: AudioAssetInspecting,
        logger: AudioTranscodingLogging = DebugLogAudioTranscodingLogger(),
        clock: @escaping () -> Date = Date.init
    ) {
        self.format = format
        self.validator = validator
        self.exporter = exporter
        self.inspector = inspector
        self.logger = logger
        self.clock = clock
    }

    func transcode(sourceURL: URL, outputURL: URL) async throws -> AudioAssetInspection {
        let startedAt = clock()
        let sourceInspection = try await inspectSource(url: sourceURL)

        logger.log(event: "AUDIO_TRANSCODE_BEGIN", metadata: metadata(
            sourceExtension: sourceInspection.pathExtension,
            sourceSizeBytes: sourceInspection.fileSizeBytes,
            durationSeconds: sourceInspection.durationSeconds
        ))

        logger.log(event: "AUDIO_TRANSCODE_EXPORT_CREATED", metadata: [
            "destination_path": outputURL.path,
            "format_extension": format.fileExtension
        ])

        do {
            try await exporter.export(sourceURL: sourceURL, destinationURL: outputURL, format: format)
            let outputInspection = try await validator.validate(url: outputURL)
            logger.log(event: "AUDIO_TRANSCODE_SUCCESS", metadata: [
                "elapsed_ms": "\(millisecondsSince(startedAt))",
                "output_extension": outputInspection.pathExtension,
                "output_size_bytes": "\(outputInspection.fileSizeBytes)",
                "duration_seconds": String(format: "%.2f", outputInspection.durationSeconds)
            ])
            return outputInspection
        } catch let error as AudioTranscodingError {
            logger.log(event: "AUDIO_TRANSCODE_FAILED", metadata: [
                "elapsed_ms": "\(millisecondsSince(startedAt))",
                "reason": error.localizedDescription
            ])
            throw error
        } catch {
            let wrappedError = AudioTranscodingError.exportFailed(reason: error.localizedDescription)
            logger.log(event: "AUDIO_TRANSCODE_FAILED", metadata: [
                "elapsed_ms": "\(millisecondsSince(startedAt))",
                "reason": wrappedError.localizedDescription
            ])
            throw wrappedError
        }
    }

    private func inspectSource(url: URL) async throws -> AudioAssetInspection {
        do {
            return try await inspector.inspect(url: url)
        } catch let error as AudioAssetInspectionError {
            switch error {
            case let .unsupportedSource(fileExtension):
                throw AudioTranscodingError.unsupportedSource(extension: fileExtension)
            case .sourceReadFailed, .missingAudioTrack, .invalidDuration, .metadataUnavailable:
                throw AudioTranscodingError.sourceReadFailed
            }
        } catch {
            throw AudioTranscodingError.sourceReadFailed
        }
    }

    private func metadata(
        sourceExtension: String,
        sourceSizeBytes: Int64,
        durationSeconds: Double
    ) -> [String: String] {
        [
            "source_extension": sourceExtension,
            "source_size_bytes": "\(sourceSizeBytes)",
            "duration_seconds": String(format: "%.2f", durationSeconds)
        ]
    }

    private func millisecondsSince(_ startedAt: Date) -> Int {
        Int(clock().timeIntervalSince(startedAt) * 1000)
    }
}

struct ImportedAudioPreparationService: ImportedAudioPreparing {
    let format: CanonicalAudioFormat
    let inspector: AudioAssetInspecting
    let matcher: CanonicalAudioMatcher
    let validator: CanonicalAudioValidating
    let transcoder: AudioTranscoding
    let fileManager: FileManager
    let temporaryDirectoryProvider: () -> URL
    let logger: AudioTranscodingLogging

    init(
        format: CanonicalAudioFormat = .speech,
        inspector: AudioAssetInspecting,
        matcher: CanonicalAudioMatcher = CanonicalAudioMatcher(),
        validator: CanonicalAudioValidating,
        transcoder: AudioTranscoding,
        fileManager: FileManager = .default,
        temporaryDirectoryProvider: @escaping () -> URL = { FileManager.default.temporaryDirectory },
        logger: AudioTranscodingLogging = DebugLogAudioTranscodingLogger()
    ) {
        self.format = format
        self.inspector = inspector
        self.matcher = matcher
        self.validator = validator
        self.transcoder = transcoder
        self.fileManager = fileManager
        self.temporaryDirectoryProvider = temporaryDirectoryProvider
        self.logger = logger
    }

    func prepare(sourceURL: URL, destinationURL: URL) async throws -> PreparedAudioFile {
        let sourceInspection = try await inspectSource(url: sourceURL)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if matcher.matches(sourceInspection) {
            logger.log(event: "AUDIO_TRANSCODE_BYPASS_CANONICAL", metadata: [
                "source_extension": sourceInspection.pathExtension,
                "source_size_bytes": "\(sourceInspection.fileSizeBytes)",
                "duration_seconds": String(format: "%.2f", sourceInspection.durationSeconds)
            ])
            try replaceItem(at: destinationURL) {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
            }
            let outputInspection = try await validator.validate(url: destinationURL)
            return PreparedAudioFile(
                fileURL: destinationURL,
                inspection: outputInspection,
                strategy: .bypassedCanonical
            )
        }

        let temporaryOutputURL = makeTemporaryOutputURL(for: destinationURL)
        defer {
            if fileManager.fileExists(atPath: temporaryOutputURL.path) {
                do {
                    try fileManager.removeItem(at: temporaryOutputURL)
                } catch {
                    logger.log(event: "AUDIO_TRANSCODE_FAILED", metadata: [
                        "reason": "temporary cleanup failed: \(error.localizedDescription)",
                        "temporary_path": temporaryOutputURL.path
                    ])
                }
            }
        }

        let outputInspection = try await transcoder.transcode(sourceURL: sourceURL, outputURL: temporaryOutputURL)
        try replaceItem(at: destinationURL) {
            try fileManager.moveItem(at: temporaryOutputURL, to: destinationURL)
        }

        return PreparedAudioFile(
            fileURL: destinationURL,
            inspection: outputInspection,
            strategy: .transcoded
        )
    }

    private func inspectSource(url: URL) async throws -> AudioAssetInspection {
        do {
            return try await inspector.inspect(url: url)
        } catch let error as AudioAssetInspectionError {
            switch error {
            case let .unsupportedSource(fileExtension):
                throw AudioTranscodingError.unsupportedSource(extension: fileExtension)
            case .sourceReadFailed, .missingAudioTrack, .invalidDuration, .metadataUnavailable:
                throw AudioTranscodingError.sourceReadFailed
            }
        } catch {
            throw AudioTranscodingError.sourceReadFailed
        }
    }

    private func replaceItem(at destinationURL: URL, writer: () throws -> Void) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try writer()
    }

    private func makeTemporaryOutputURL(for destinationURL: URL) -> URL {
        let baseName = destinationURL.deletingPathExtension().lastPathComponent
        let tempFileName = "\(baseName).transcoding.\(ProcessInfo.processInfo.globallyUniqueString).\(format.fileExtension)"
        return temporaryDirectoryProvider().appendingPathComponent(tempFileName)
    }
}

struct AVAssetReaderWriterAudioExporter: AudioTranscodeExporting {
    func export(sourceURL: URL, destinationURL: URL, format: CanonicalAudioFormat) async throws {
        let asset = AVURLAsset(url: sourceURL)
        let audioTracks: [AVAssetTrack]
        do {
            audioTracks = try await asset.loadTracks(withMediaType: .audio)
        } catch {
            throw AudioTranscodingError.sourceReadFailed
        }
        guard let audioTrack = audioTracks.first else {
            throw AudioTranscodingError.sourceReadFailed
        }

        let reader: AVAssetReader
        let writer: AVAssetWriter
        do {
            reader = try AVAssetReader(asset: asset)
            writer = try AVAssetWriter(outputURL: destinationURL, fileType: format.fileType)
        } catch {
            throw AudioTranscodingError.exportCreationFailed
        }

        let readerOutput = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVNumberOfChannelsKey: format.channelCount,
                AVSampleRateKey: format.sampleRate
            ]
        )
        guard reader.canAdd(readerOutput) else {
            throw AudioTranscodingError.exportCreationFailed
        }
        reader.add(readerOutput)

        let writerInput = AVAssetWriterInput(
            mediaType: .audio,
            outputSettings: [
                AVFormatIDKey: format.codecFormatID,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: format.channelCount,
                AVEncoderBitRateKey: format.targetBitRate,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
        )
        writerInput.expectsMediaDataInRealTime = false
        guard writer.canAdd(writerInput) else {
            throw AudioTranscodingError.exportCreationFailed
        }
        writer.add(writerInput)

        guard reader.startReading() else {
            throw AudioTranscodingError.exportCreationFailed
        }
        guard writer.startWriting() else {
            throw AudioTranscodingError.exportCreationFailed
        }

        writer.startSession(atSourceTime: .zero)

        let queue = DispatchQueue(label: "familyrosary.audio.transcode")
        let exportContext = ReaderWriterExportContext(
            reader: reader,
            writer: writer,
            readerOutput: readerOutput,
            writerInput: writerInput
        )
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let stateQueue = DispatchQueue(label: "familyrosary.audio.transcode.state")
            var hasResumed = false

            func finish(_ result: Result<Void, AudioTranscodingError>) {
                stateQueue.sync {
                    guard hasResumed == false else {
                        return
                    }
                    hasResumed = true
                    continuation.resume(with: result)
                }
            }

            exportContext.writerInput.requestMediaDataWhenReady(on: queue) {
                while exportContext.writerInput.isReadyForMoreMediaData {
                    if let sampleBuffer = exportContext.readerOutput.copyNextSampleBuffer() {
                        if exportContext.writerInput.append(sampleBuffer) == false {
                            exportContext.writerInput.markAsFinished()
                            exportContext.reader.cancelReading()
                            finish(.failure(.exportFailed(reason: exportContext.writer.error?.localizedDescription ?? "writer append failed")))
                            return
                        }
                        continue
                    }

                    exportContext.writerInput.markAsFinished()

                    if exportContext.reader.status == .failed {
                        finish(.failure(.exportFailed(reason: exportContext.reader.error?.localizedDescription ?? "reader failed")))
                        return
                    }

                    if exportContext.reader.status == .cancelled {
                        finish(.failure(.exportCancelled))
                        return
                    }

                    exportContext.writer.finishWriting {
                        if exportContext.writer.status == .failed {
                            finish(.failure(.exportFailed(reason: exportContext.writer.error?.localizedDescription ?? "writer failed")))
                        } else if exportContext.writer.status == .cancelled {
                            finish(.failure(.exportCancelled))
                        } else {
                            finish(.success(()))
                        }
                    }
                    return
                }
            }
        }
    }
}

private final class ReaderWriterExportContext: @unchecked Sendable {
    let reader: AVAssetReader
    let writer: AVAssetWriter
    let readerOutput: AVAssetReaderTrackOutput
    let writerInput: AVAssetWriterInput

    init(
        reader: AVAssetReader,
        writer: AVAssetWriter,
        readerOutput: AVAssetReaderTrackOutput,
        writerInput: AVAssetWriterInput
    ) {
        self.reader = reader
        self.writer = writer
        self.readerOutput = readerOutput
        self.writerInput = writerInput
    }
}
