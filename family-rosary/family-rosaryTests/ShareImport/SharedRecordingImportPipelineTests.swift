import AudioToolbox
import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class SharedRecordingImportPipelineTests: XCTestCase {
    func testPipelineSuccessCopiesSavesPendingImportAndCleansUp() async throws {
        let fixture = try PipelineFixture.make()
        let importID = "success-1"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let pipeline = fixture.makePipeline()
        let result = await pipeline.process(importID: importID)

        switch result.status {
        case .pendingMetadata(let pendingImport):
            XCTAssertEqual(pendingImport.id, importID)
            XCTAssertEqual(pendingImport.importID, importID)
            XCTAssertEqual(pendingImport.originalFilename, "Memo.m4a")
            let destinationURL = fixture.baseDirURL
                .appendingPathComponent("imported_shared_audio", isDirectory: true)
                .appendingPathComponent("shared_success-1_memo.m4a")
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
            XCTAssertEqual(try fixture.pendingImportStore.all(), [pendingImport])
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagedFolderURL(importID: importID).path))
        case .failed(let message):
            XCTFail("Expected success, got failure: \(message)")
        }
    }

    func testPipelineSuccessWritesPendingImportThatCanBeReadBackImmediately() async throws {
        let fixture = try PipelineFixture.make()
        let importID = "success-readback"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let result = await fixture.makePipeline().process(importID: importID)

        switch result.status {
        case .pendingMetadata(let pendingImport):
            let stored = try fixture.pendingImportStore.all()
            XCTAssertEqual(stored.count, 1)
            XCTAssertEqual(stored.first, pendingImport)
        case .failed(let message):
            XCTFail("Expected success, got failure: \(message)")
        }
    }

    func testPipelineFailsWhenReceiptMissing() async throws {
        let fixture = try PipelineFixture.make()
        let importID = "missing-receipt"
        try fixture.writeStagedImport(importID: importID, receipt: false, audioData: Data("audio".utf8))

        let result = await fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "receipt is missing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.stagedFolderURL(importID: importID).path))
    }

    func testPipelineFailsWhenAudioMissing() async throws {
        let fixture = try PipelineFixture.make()
        let importID = "missing-audio"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: nil)

        let result = await fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "could not be found")
    }

    func testPipelineFailsWhenAudioIsZeroBytes() async throws {
        let fixture = try PipelineFixture.make()
        let importID = "zero-bytes"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data())

        let result = await fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "empty (0 bytes)")
    }

    func testPipelineFailsWhenAudioUndecodable() async throws {
        let fixture = try PipelineFixture.make(audioInspector: FailingAudioInspector())
        let importID = "undecodable"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let result = await fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "could not decode")
    }

    func testPipelineFailsWhenCopyIntoLibraryFails() async throws {
        let fixture = try PipelineFixture.make(
            audioPreparationService: FailingImportedAudioPreparationService(
                error: AudioTranscodingError.exportCreationFailed
            ),
            fileManager: AlwaysFailingCopyFileManager()
        )
        let importID = "copy-fail"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let result = await fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "canonical format")
    }

    func testProcessAllPendingUsesStableOrdering() async throws {
        let fixture = try PipelineFixture.make()
        try fixture.writeStagedImport(importID: "b", receipt: true, audioData: Data("audio".utf8))
        try fixture.writeStagedImport(importID: "a", receipt: true, audioData: Data("audio".utf8))

        let results = await fixture.makePipeline().processAllPending()
        XCTAssertEqual(results.map(\.importID), ["a", "b"])
    }

    private func assertFailure(_ result: SharedRecordingImportResult, contains text: String) {
        switch result.status {
        case .pendingMetadata:
            XCTFail("Expected failure.")
        case .failed(let message):
            XCTAssertTrue(message.localizedCaseInsensitiveContains(text))
        }
    }
}

private struct PipelineFixture {
    let containerURL: URL
    let baseDirURL: URL
    let paths: SharedImportPaths
    let discovery: SharedRecordingDiscoveryService
    let audioInspector: SharedAudioInspecting
    let audioPreparationService: ImportedAudioPreparing
    let pendingImportStore: FileBackedPendingImportStore
    let fileManager: FileManager

    static func make(
        audioInspector: SharedAudioInspecting = PassingAudioInspector(),
        audioPreparationService: ImportedAudioPreparing = PassingImportedAudioPreparationService(),
        fileManager: FileManager = .default
    ) throws -> PipelineFixture {
        let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: baseDirURL, withIntermediateDirectories: true)

        let paths = SharedImportPaths(
            fileManager: fileManager,
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )
        _ = try paths.ensureSharedInboxDirectory()
        let discovery = SharedRecordingDiscoveryService(paths: paths, fileManager: fileManager)
        let store = FileBackedPendingImportStore(
            fileManager: fileManager,
            indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
        )
        return PipelineFixture(
            containerURL: containerURL,
            baseDirURL: baseDirURL,
            paths: paths,
            discovery: discovery,
            audioInspector: audioInspector,
            audioPreparationService: audioPreparationService,
            pendingImportStore: store,
            fileManager: fileManager
        )
    }

    func makePipeline() -> SharedRecordingImportPipeline {
        SharedRecordingImportPipeline(
            paths: paths,
            discoveryService: discovery,
            audioInspector: audioInspector,
            audioPreparationService: audioPreparationService,
            pendingImportStore: pendingImportStore,
            fileManager: fileManager,
            sessionIDProvider: { "session" },
            nowProvider: { Date(timeIntervalSince1970: 10) },
            baseDirURLProvider: { baseDirURL }
        )
    }

    func stagedFolderURL(importID: String) -> URL {
        containerURL.appendingPathComponent("SharedInbox/\(importID)", isDirectory: true)
    }

    func writeStagedImport(importID: String, receipt: Bool, audioData: Data?) throws {
        let folderURL = stagedFolderURL(importID: importID)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        let audioFilename = "memo.m4a"

        if let audioData {
            try audioData.write(to: folderURL.appendingPathComponent(audioFilename))
        }

        if receipt {
            let receipt = SharedRecordingReceipt(
                importID: importID,
                sourceFilename: "Memo.m4a",
                normalizedFilename: audioFilename,
                stagedAudioFilename: audioFilename,
                sourceTypeIdentifier: "public.mpeg-4-audio",
                byteCount: Int64(audioData?.count ?? 0),
                stagedAtISO8601: "2026-03-30T00:00:00.000Z"
            )
            let data = try JSONEncoder().encode(receipt)
            try data.write(to: folderURL.appendingPathComponent("receipt.json"))
        }
    }
}

private struct PassingAudioInspector: SharedAudioInspecting {
    func inspect(url: URL) throws -> SharedAudioInspection {
        _ = url
        return SharedAudioInspection(durationSeconds: 4.2)
    }
}

private struct FailingAudioInspector: SharedAudioInspecting {
    func inspect(url: URL) throws -> SharedAudioInspection {
        _ = url
        throw SharedAudioInspectionError.invalidDuration
    }
}

private final class AlwaysFailingCopyFileManager: FileManager {
    override func copyItem(at srcURL: URL, to dstURL: URL) throws {
        _ = srcURL
        _ = dstURL
        throw NSError(domain: "tests", code: 999, userInfo: [NSLocalizedDescriptionKey: "copy failed"])
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

private struct FailingImportedAudioPreparationService: ImportedAudioPreparing {
    let error: Error

    func prepare(sourceURL: URL, destinationURL: URL) async throws -> PreparedAudioFile {
        _ = sourceURL
        _ = destinationURL
        throw error
    }
}
