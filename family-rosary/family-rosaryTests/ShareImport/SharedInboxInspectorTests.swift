import Foundation
import XCTest
@testable import family_rosary

final class SharedInboxInspectorTests: XCTestCase {
    func testListsInboxItemsAndSizes() throws {
        let containerURL = makeTempDirectory()
        let paths = SharedImportPaths(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )
        try paths.ensureSharedInboxDirectory()
        try writeStagedImport(containerURL: containerURL, importID: "abc", audioExists: true)

        let inspector = SharedInboxInspector(paths: paths)
        let items = inspector.inspect()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].importID, "abc")
        XCTAssertEqual(items[0].stagedFilename, "memo.m4a")
        XCTAssertEqual(items[0].byteSize, 5)
        XCTAssertTrue(items[0].fileExistsAtManifestPath)
    }

    func testReportsMissingReferencedFiles() throws {
        let containerURL = makeTempDirectory()
        let paths = SharedImportPaths(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )
        try paths.ensureSharedInboxDirectory()
        try writeStagedImport(containerURL: containerURL, importID: "missing", audioExists: false)

        let inspector = SharedInboxInspector(paths: paths)
        let items = inspector.inspect()

        XCTAssertEqual(items.count, 1)
        XCTAssertFalse(items[0].fileExistsAtManifestPath)
    }

    private func writeStagedImport(containerURL: URL, importID: String, audioExists: Bool) throws {
        let folderURL = containerURL.appendingPathComponent("SharedInbox/\(importID)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)
        if audioExists {
            try Data("audio".utf8).write(to: folderURL.appendingPathComponent("memo.m4a"))
        }

        let receipt = SharedRecordingReceipt(
            importID: importID,
            sourceFilename: "Memo.m4a",
            normalizedFilename: "memo.m4a",
            stagedAudioFilename: "memo.m4a",
            sourceTypeIdentifier: "public.mpeg-4-audio",
            byteCount: 5,
            stagedAtISO8601: "2026-04-11T12:00:00.000Z"
        )
        try JSONEncoder().encode(receipt).write(to: folderURL.appendingPathComponent("receipt.json"))
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
