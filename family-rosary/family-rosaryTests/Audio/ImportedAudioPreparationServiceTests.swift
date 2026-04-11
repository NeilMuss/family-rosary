import AudioToolbox
import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class ImportedAudioPreparationServiceTests: XCTestCase {
    func testPrepareBypassesAlreadyCanonicalAudioAndCopiesToDestination() async throws {
        let sourceURL = try makeFile(named: "source.m4a", contents: "canonical-source")
        let destinationURL = temporaryDirectory().appendingPathComponent("dad_hail_lead.m4a")
        let canonicalInspection = AudioAssetInspection(
            pathExtension: "m4a",
            fileSizeBytes: 15,
            durationSeconds: 4.2,
            sampleRate: 24_000,
            channelCount: 1,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )

        let transcoder = StubAudioTranscoder()
        let service = ImportedAudioPreparationService(
            inspector: StubAudioInspector(inspections: [sourceURL.path: canonicalInspection]),
            matcher: CanonicalAudioMatcher(format: .speech),
            validator: StubCanonicalAudioValidator(inspections: [destinationURL.path: canonicalInspection]),
            transcoder: transcoder,
            temporaryDirectoryProvider: { self.temporaryDirectory() }
        )

        let prepared = try await service.prepare(sourceURL: sourceURL, destinationURL: destinationURL)

        XCTAssertEqual(prepared.fileURL, destinationURL)
        XCTAssertEqual(prepared.strategy, .bypassedCanonical)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertEqual(try String(contentsOf: destinationURL), "canonical-source")
        XCTAssertTrue(transcoder.calls.isEmpty)
    }

    func testPrepareTranscodesNonCanonicalAudioAndCleansUpTemporaryOutput() async throws {
        let sourceURL = try makeFile(named: "source.wav", contents: "pcm")
        let destinationURL = temporaryDirectory().appendingPathComponent("dad_hail_lead.m4a")
        let sourceInspection = AudioAssetInspection(
            pathExtension: "wav",
            fileSizeBytes: 3,
            durationSeconds: 4.2,
            sampleRate: 44_100,
            channelCount: 1,
            codecFormatID: kAudioFormatLinearPCM,
            estimatedBitRate: nil
        )
        let outputInspection = AudioAssetInspection(
            pathExtension: "m4a",
            fileSizeBytes: 8,
            durationSeconds: 4.2,
            sampleRate: 24_000,
            channelCount: 1,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )

        let transcoder = StubAudioTranscoder { _, outputURL in
            try Data("aac-data".utf8).write(to: outputURL)
            return outputInspection
        }
        let service = ImportedAudioPreparationService(
            inspector: StubAudioInspector(inspections: [sourceURL.path: sourceInspection]),
            matcher: CanonicalAudioMatcher(format: .speech),
            validator: StubCanonicalAudioValidator(inspections: [:]),
            transcoder: transcoder,
            temporaryDirectoryProvider: { self.temporaryDirectory() }
        )

        let prepared = try await service.prepare(sourceURL: sourceURL, destinationURL: destinationURL)

        XCTAssertEqual(prepared.strategy, .transcoded)
        XCTAssertEqual(try String(contentsOf: destinationURL), "aac-data")
        XCTAssertEqual(transcoder.calls.count, 1)
        XCTAssertEqual(transcoder.calls[0].sourceURL, sourceURL)
        XCTAssertFalse(FileManager.default.fileExists(atPath: transcoder.calls[0].outputURL.path))
    }

    func testCanonicalValidatorRejectsZeroByteOutputs() async throws {
        let destinationURL = temporaryDirectory().appendingPathComponent("empty.m4a")
        try Data().write(to: destinationURL)

        let validator = CanonicalAudioValidator(
            inspector: StubAudioInspector(inspections: [:]),
            matcher: CanonicalAudioMatcher(format: .speech)
        )

        do {
            _ = try await validator.validate(url: destinationURL)
            XCTFail("Expected validation failure.")
        } catch {
            XCTAssertEqual(
                error.localizedDescription,
                AudioTranscodingError.outputInvalid(reason: "file size was 0 bytes").localizedDescription
            )
        }
    }

    func testAudioImportUseCaseWrapsCanonicalizationFailuresPrecisely() async throws {
        let useCase = AudioImportUseCase(
            baseDirURL: { self.temporaryDirectory() },
            audioPreparationService: FailingAudioPreparationService(
                error: AudioTranscodingError.exportCreationFailed
            )
        )
        let sourceURL = try makeFile(named: "source.wav", contents: "wave")

        do {
            _ = try await useCase.import(sourceURL: sourceURL, personID: "dad", slot: .hailMaryLead)
            XCTFail("Expected import failure.")
        } catch {
            XCTAssertEqual(error.localizedDescription, "Import failed: Audio conversion could not start.")
        }
    }

    private func makeFile(named name: String, contents: String) throws -> URL {
        let fileURL = temporaryDirectory().appendingPathComponent(name)
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(contents.utf8).write(to: fileURL)
        return fileURL
    }

    private func temporaryDirectory() -> URL {
        let directoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        return directoryURL
    }
}

private struct StubAudioInspector: AudioAssetInspecting {
    let inspections: [String: AudioAssetInspection]

    func inspect(url: URL) async throws -> AudioAssetInspection {
        guard let inspection = inspections[url.path] else {
            throw AudioAssetInspectionError.sourceReadFailed
        }
        return inspection
    }
}

private struct StubCanonicalAudioValidator: CanonicalAudioValidating {
    let inspections: [String: AudioAssetInspection]

    func validate(url: URL) async throws -> AudioAssetInspection {
        guard let inspection = inspections[url.path] else {
            throw AudioTranscodingError.outputInvalid(reason: "missing stubbed validation")
        }
        return inspection
    }
}

private final class StubAudioTranscoder: AudioTranscoding {
    struct Call: Equatable {
        let sourceURL: URL
        let outputURL: URL
    }

    private let handler: (URL, URL) async throws -> AudioAssetInspection
    private(set) var calls: [Call] = []

    init(handler: @escaping (URL, URL) async throws -> AudioAssetInspection = { _, _ in
        AudioAssetInspection(
            pathExtension: "m4a",
            fileSizeBytes: 8,
            durationSeconds: 4.2,
            sampleRate: 24_000,
            channelCount: 1,
            codecFormatID: kAudioFormatMPEG4AAC,
            estimatedBitRate: 48_000
        )
    }) {
        self.handler = handler
    }

    func transcode(sourceURL: URL, outputURL: URL) async throws -> AudioAssetInspection {
        calls.append(Call(sourceURL: sourceURL, outputURL: outputURL))
        return try await handler(sourceURL, outputURL)
    }
}

private struct FailingAudioPreparationService: ImportedAudioPreparing {
    let error: Error

    func prepare(sourceURL: URL, destinationURL: URL) async throws -> PreparedAudioFile {
        _ = sourceURL
        _ = destinationURL
        throw error
    }
}
