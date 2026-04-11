import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class SharedInboxScanCoordinatorTests: XCTestCase {
    func testScanLogsZeroItems() async throws {
        let fixture = try Fixture.make()
        let coordinator = fixture.makeCoordinator(discoveredItems: [], results: [])

        await coordinator.scanSharedInboxNow()

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("SCAN_NOW | BEGIN"))
        XCTAssertTrue(lines.contains("SCAN_NOW | ZERO_ITEMS"))
    }

    func testScanLogsPendingItemsFoundAndPerItemResults() async throws {
        let fixture = try Fixture.make()
        let discovered = [
            SharedRecordingDiscoveredItem(
                id: "a",
                importID: "a",
                folderURL: fixture.containerURL.appendingPathComponent("SharedInbox/a", isDirectory: true),
                receiptURL: fixture.containerURL.appendingPathComponent("SharedInbox/a/receipt.json"),
                receipt: nil,
                audioFileURL: nil,
                status: .ready
            )
        ]
        let results = [
            SharedRecordingImportResult(
                importID: "a",
                status: .failed(message: "copy failed")
            )
        ]
        let coordinator = fixture.makeCoordinator(discoveredItems: discovered, results: results)

        await coordinator.scanSharedInboxNow()

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("SCAN_NOW | FOUND | count=1"))
        XCTAssertTrue(lines.contains("APP_IMPORT | FAIL | importID=a reason=copy failed"))
    }

    private struct Fixture {
        let containerURL: URL
        let logStore: SharedDiagnosticsLogStore
        let paths: SharedImportPaths

        static func make() throws -> Fixture {
            let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            let paths = SharedImportPaths(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )
            let logStore = SharedDiagnosticsLogStore(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )
            return Fixture(containerURL: containerURL, logStore: logStore, paths: paths)
        }

        func makeCoordinator(
            discoveredItems: [SharedRecordingDiscoveredItem],
            results: [SharedRecordingImportResult]
        ) -> SharedInboxScanCoordinator {
            SharedInboxScanCoordinator(
                inspector: SharedInboxInspector(paths: paths),
                discoveryService: StubDiscovery(items: discoveredItems),
                pipeline: StubPipeline(results: results),
                paths: paths,
                logStore: logStore,
                logger: SharedDiagnosticsLogger(
                    category: "APP_IMPORT",
                    store: logStore,
                    mirrorToDebugLog: false
                )
            )
        }
    }
}

private struct StubDiscovery: SharedRecordingDiscovering {
    let items: [SharedRecordingDiscoveredItem]
    func discover() -> [SharedRecordingDiscoveredItem] { items }
}

private struct StubPipeline: SharedRecordingImportRunning {
    let results: [SharedRecordingImportResult]
    func processAllPending() async -> [SharedRecordingImportResult] { results }
    func process(importID: String) async -> SharedRecordingImportResult {
        results.first { $0.importID == importID } ?? SharedRecordingImportResult(importID: importID, status: .failed(message: "missing"))
    }
}
