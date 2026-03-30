import Foundation
import XCTest
@testable import family_rosary

final class SharedRecordingDiscoveryServiceTests: XCTestCase {
    func testDiscoverFindsStagedImportsInStableOrder() throws {
        let containerURL = makeTempDirectory()
        let paths = SharedImportPaths(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )
        try paths.ensureSharedInboxDirectory()

        try writeStagedImport(importID: "b-import", containerURL: containerURL, includeReceipt: true, includeAudio: true)
        try writeStagedImport(importID: "a-import", containerURL: containerURL, includeReceipt: true, includeAudio: true)

        let service = SharedRecordingDiscoveryService(paths: paths)
        let items = service.discover()

        XCTAssertEqual(items.map(\.importID), ["a-import", "b-import"])
        XCTAssertEqual(items.map(\.status), [.ready, .ready])
    }

    func testDiscoverMarksMalformedWhenReceiptMissing() throws {
        let containerURL = makeTempDirectory()
        let paths = SharedImportPaths(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )
        try paths.ensureSharedInboxDirectory()

        try writeStagedImport(importID: "missing-receipt", containerURL: containerURL, includeReceipt: false, includeAudio: true)

        let service = SharedRecordingDiscoveryService(paths: paths)
        let items = service.discover()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].importID, "missing-receipt")
        XCTAssertEqual(items[0].status, .malformed(reason: "The staged shared import receipt is missing."))
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func writeStagedImport(
        importID: String,
        containerURL: URL,
        includeReceipt: Bool,
        includeAudio: Bool
    ) throws {
        let folderURL = containerURL.appendingPathComponent("SharedInbox/\(importID)", isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true)

        let audioFilename = "memo.m4a"
        if includeAudio {
            try Data("audio".utf8).write(to: folderURL.appendingPathComponent(audioFilename))
        }

        if includeReceipt {
            let receipt = SharedRecordingReceipt(
                importID: importID,
                sourceFilename: "Memo.m4a",
                normalizedFilename: audioFilename,
                stagedAudioFilename: audioFilename,
                sourceTypeIdentifier: "public.mpeg-4-audio",
                byteCount: 5,
                stagedAtISO8601: "2026-03-30T00:00:00.000Z"
            )
            let receiptData = try JSONEncoder().encode(receipt)
            try receiptData.write(to: folderURL.appendingPathComponent("receipt.json"))
        }
    }
}
