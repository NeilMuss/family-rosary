import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class SharedDiagnosticsLogStoreTests: XCTestCase {
    func testAppendAndLoadEntries() throws {
        let containerURL = makeTempDirectory()
        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )

        try store.append(SharedDiagnosticsEntry(
            timestampISO8601: "2026-04-11T12:00:00.000Z",
            category: "SHARE_EXT",
            stage: "SESSION_BEGIN",
            event: "INFO",
            detail: "first"
        ))
        try store.append(SharedDiagnosticsEntry(
            timestampISO8601: "2026-04-11T12:00:01.000Z",
            category: "APP_IMPORT",
            stage: "SCAN_NOW",
            event: "SUCCESS",
            detail: "second"
        ))

        let entries = try store.loadEntries()
        XCTAssertEqual(entries.count, 2)
        XCTAssertEqual(entries[0].category, "SHARE_EXT")
        XCTAssertEqual(entries[1].category, "APP_IMPORT")
    }

    func testClearEntriesRemovesLogFile() throws {
        let containerURL = makeTempDirectory()
        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )

        try store.append(SharedDiagnosticsEntry(
            timestampISO8601: "2026-04-11T12:00:00.000Z",
            category: "SHARE_EXT",
            stage: "SESSION_BEGIN",
            event: "INFO",
            detail: nil
        ))
        try store.clear()

        XCTAssertEqual(try store.loadEntries(), [])
    }

    func testResolvedURLsUseSharedDiagnosticsLayout() throws {
        let containerURL = makeTempDirectory()
        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )

        XCTAssertEqual(try store.containerURL().path, containerURL.path)
        XCTAssertEqual(
            try store.diagnosticsDirectoryURL().path,
            containerURL.appendingPathComponent("SharedDiagnostics", isDirectory: true).path
        )
        XCTAssertEqual(
            try store.logFileURL().path,
            containerURL.appendingPathComponent("SharedDiagnostics/entries.jsonl").path
        )
    }

    func testFormattedLineProducesReadableText() {
        let entry = SharedDiagnosticsEntry(
            timestampISO8601: "2026-04-11T12:00:00.000Z",
            category: "APP",
            stage: "SESSION_BEGIN",
            event: "INFO",
            detail: "detail=value"
        )

        XCTAssertEqual(
            entry.formattedLine,
            "2026-04-11T12:00:00.000Z | APP | SESSION_BEGIN | INFO | detail=value"
        )
    }

    func testUnavailableContainerSurfacesDeterministicError() {
        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { nil }
        )

        XCTAssertThrowsError(try store.logFileURL()) { error in
            XCTAssertEqual(
                error as? SharedDiagnosticsLogStoreError,
                .appGroupContainerUnavailable(appGroupIdentifier: "group.com.neilmussett.familyrosary")
            )
        }
    }

    private func makeTempDirectory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }
}
