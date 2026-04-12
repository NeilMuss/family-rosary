import AudioToolbox
import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class SharedAudioStagingServiceTests: XCTestCase {
    func testServiceStagesFileAndWritesExpectedReceipt() throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeSourceFile(filename: "Debug Share Seed.m4a", data: Data("audio".utf8))

        let result = try fixture.makeService().stage(
            SharedAudioStagingRequest(
                sourceFileURL: sourceURL,
                sourceFilename: sourceURL.lastPathComponent,
                sourceTypeIdentifier: "public.mpeg-4-audio",
                byteCount: nil
            )
        )

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.stagedAudioURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.receiptURL.path))

        let receiptData = try Data(contentsOf: result.receiptURL)
        let receipt = try JSONDecoder().decode(SharedRecordingReceipt.self, from: receiptData)
        XCTAssertEqual(receipt.importID, result.importID)
        XCTAssertEqual(receipt.sourceFilename, "Debug Share Seed.m4a")
        XCTAssertEqual(receipt.normalizedFilename, "debug_share_seed.m4a")
        XCTAssertEqual(receipt.stagedAudioFilename, "debug_share_seed.m4a")
        XCTAssertEqual(receipt.byteCount, 5)
    }

    func testStagedResultIsConsumableByAppDiscoveryAndImportPipeline() async throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeSourceFile(filename: "debug_share_seed.m4a", data: Data("audio".utf8))

        let result = try fixture.makeService().stage(
            SharedAudioStagingRequest(
                sourceFileURL: sourceURL,
                sourceFilename: sourceURL.lastPathComponent,
                sourceTypeIdentifier: "public.mpeg-4-audio",
                byteCount: 5
            )
        )

        let discovered = fixture.discovery.discover()
        XCTAssertTrue(discovered.contains(where: { $0.importID == result.importID && $0.status == .ready }))

        let pipelineResult = await fixture.makePipeline().process(importID: result.importID)
        switch pipelineResult.status {
        case .pendingMetadata(let pendingImport):
            XCTAssertEqual(pendingImport.importID, result.importID)
            XCTAssertTrue(pendingImport.libraryFileURL.lastPathComponent.contains(result.importID))
        case .failed(let message):
            XCTFail("Expected staged result to import successfully, got: \(message)")
        }
    }

    private struct Fixture {
        let containerURL: URL
        let sourceDirectoryURL: URL
        let baseDirURL: URL
        let paths: SharedImportPaths
        let discovery: SharedRecordingDiscoveryService

        @MainActor
        static func make() throws -> Fixture {
            let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let sourceDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: sourceDirectoryURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: baseDirURL, withIntermediateDirectories: true)

            let paths = SharedImportPaths(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )
            return Fixture(
                containerURL: containerURL,
                sourceDirectoryURL: sourceDirectoryURL,
                baseDirURL: baseDirURL,
                paths: paths,
                discovery: SharedRecordingDiscoveryService(paths: paths)
            )
        }

        func makeSourceFile(filename: String, data: Data) throws -> URL {
            let url = sourceDirectoryURL.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            return url
        }

        @MainActor
        func makeService() -> SharedAudioStagingService {
            SharedAudioStagingService(
                appGroupIdentifier: paths.appGroupIdentifier,
                logger: StagingLoggerSpy(),
                sharedContainerURLProvider: { containerURL }
            )
        }

        @MainActor
        func makePipeline() -> SharedRecordingImportPipeline {
            SharedRecordingImportPipeline(
                paths: paths,
                discoveryService: discovery,
                audioInspector: PassingAudioInspector(),
                audioPreparationService: PassingImportedAudioPreparationService(),
                pendingImportStore: FileBackedPendingImportStore(
                    indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                sessionIDProvider: { "session" },
                nowProvider: { Date(timeIntervalSince1970: 10) },
                baseDirURLProvider: { baseDirURL }
            )
        }
    }
}

private struct StagingLoggerSpy: SharedAudioStagingLogging {
    func log(_ stage: String, details: [String: String?]) {
        _ = stage
        _ = details
    }

    func fail(_ reason: String, stage: String, error: Error?, details: [String: String?]) {
        _ = reason
        _ = stage
        _ = error
        _ = details
    }
}

private struct PassingAudioInspector: SharedAudioInspecting {
    func inspect(url: URL) throws -> SharedAudioInspection {
        _ = url
        return SharedAudioInspection(durationSeconds: 4.2)
    }
}

private struct PassingImportedAudioPreparationService: ImportedAudioPreparing {
    func prepare(sourceURL: URL, destinationURL: URL) async throws -> PreparedAudioFile {
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return PreparedAudioFile(
            fileURL: destinationURL,
            inspection: AudioAssetInspection(
                pathExtension: "m4a",
                fileSizeBytes: (try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0,
                durationSeconds: 4.2,
                sampleRate: 24_000,
                channelCount: 1,
                codecFormatID: kAudioFormatMPEG4AAC,
                estimatedBitRate: 48_000
            ),
            strategy: .bypassedCanonical
        )
    }
}
