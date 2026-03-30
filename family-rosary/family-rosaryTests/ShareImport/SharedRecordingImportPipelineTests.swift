import Foundation
import XCTest
@testable import family_rosary

final class SharedRecordingImportPipelineTests: XCTestCase {
    func testPipelineSuccessCopiesRegistersAndCleansUp() throws {
        let fixture = try PipelineFixture.make()
        let importID = "success-1"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let pipeline = fixture.makePipeline()
        let result = pipeline.process(importID: importID)

        switch result.status {
        case .imported(let imported):
            XCTAssertTrue(imported.filename.contains(importID))
            let destinationURL = fixture.baseDirURL
                .appendingPathComponent("imported_shared_audio", isDirectory: true)
                .appendingPathComponent(imported.filename)
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.stagedFolderURL(importID: importID).path))
        case .failed(let message):
            XCTFail("Expected success, got failure: \(message)")
        }
    }

    func testPipelineFailsWhenReceiptMissing() throws {
        let fixture = try PipelineFixture.make()
        let importID = "missing-receipt"
        try fixture.writeStagedImport(importID: importID, receipt: false, audioData: Data("audio".utf8))

        let result = fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "receipt is missing")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.stagedFolderURL(importID: importID).path))
    }

    func testPipelineFailsWhenAudioMissing() throws {
        let fixture = try PipelineFixture.make()
        let importID = "missing-audio"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: nil)

        let result = fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "could not be found")
    }

    func testPipelineFailsWhenAudioIsZeroBytes() throws {
        let fixture = try PipelineFixture.make()
        let importID = "zero-bytes"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data())

        let result = fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "empty (0 bytes)")
    }

    func testPipelineFailsWhenAudioUndecodable() throws {
        let fixture = try PipelineFixture.make(audioInspector: FailingAudioInspector())
        let importID = "undecodable"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let result = fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "could not decode")
    }

    func testPipelineFailsWhenCopyIntoLibraryFails() throws {
        let fixture = try PipelineFixture.make(fileManager: AlwaysFailingCopyFileManager())
        let importID = "copy-fail"
        try fixture.writeStagedImport(importID: importID, receipt: true, audioData: Data("audio".utf8))

        let result = fixture.makePipeline().process(importID: importID)
        assertFailure(result, contains: "could not move it into its library")
    }

    func testProcessAllPendingUsesStableOrdering() throws {
        let fixture = try PipelineFixture.make()
        try fixture.writeStagedImport(importID: "b", receipt: true, audioData: Data("audio".utf8))
        try fixture.writeStagedImport(importID: "a", receipt: true, audioData: Data("audio".utf8))

        let results = fixture.makePipeline().processAllPending()
        XCTAssertEqual(results.map(\.importID), ["a", "b"])
    }

    private func assertFailure(_ result: SharedRecordingImportResult, contains text: String) {
        switch result.status {
        case .imported:
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
    let recordingStore: FileBackedImportedRecordingStore
    let fileManager: FileManager

    static func make(
        audioInspector: SharedAudioInspecting = PassingAudioInspector(),
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
        let store = FileBackedImportedRecordingStore(
            fileManager: fileManager,
            indexFileURL: FamilyRosaryPaths.importedRecordingIndexFileURL(baseDirURL: baseDirURL)
        )
        return PipelineFixture(
            containerURL: containerURL,
            baseDirURL: baseDirURL,
            paths: paths,
            discovery: discovery,
            audioInspector: audioInspector,
            recordingStore: store,
            fileManager: fileManager
        )
    }

    func makePipeline() -> SharedRecordingImportPipeline {
        SharedRecordingImportPipeline(
            paths: paths,
            discoveryService: discovery,
            audioInspector: audioInspector,
            recordingStore: recordingStore,
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
