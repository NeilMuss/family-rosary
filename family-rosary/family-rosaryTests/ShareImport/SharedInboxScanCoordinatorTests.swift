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
        XCTAssertTrue(lines.contains("APP_IMPORT | SCAN_BEGIN | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | SCAN_COMPLETE | ZERO_ITEMS"))
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
        XCTAssertTrue(lines.contains("APP_IMPORT | ITEM_FOUND | INFO | importID=a"))
        XCTAssertTrue(lines.contains("APP_IMPORT | SCAN_COMPLETE | FAIL | importID=a reason=copy failed"))
    }

    func testReadSharedContainerListsFiles() async throws {
        let fixture = try Fixture.make()
        let coordinator = fixture.makeCoordinator(discoveredItems: [], results: [])
        let inboxURL = try fixture.paths.ensureSharedInboxDirectory()
        try Data("canary".utf8).write(to: inboxURL.appendingPathComponent("app-canary.txt"))

        coordinator.readSharedContainer()

        XCTAssertTrue(coordinator.sharedContainerEntries.contains("SharedInbox/app-canary.txt"))
    }

    func testStartupSequenceLogsProofOfLifeWithoutRunningSimulatedShare() async throws {
        let fixture = try Fixture.make()
        let startupRunner = StubSimulatedShareRunner()
        let coordinator = fixture.makeCoordinator(discoveredItems: [], results: [], simulatedShareRunner: startupRunner)

        coordinator.runStartupSequenceIfNeeded()
        coordinator.runStartupSequenceIfNeeded()

        XCTAssertEqual(startupRunner.runCount, 0)

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("APP | App initialized. | INFO"))
        XCTAssertTrue(lines.contains("APP | Launch title screen showing. | INFO"))
    }

    func testLaunchScreenTransitionLogsOnlyOncePerLaunch() async throws {
        let fixture = try Fixture.make()
        let coordinator = fixture.makeCoordinator(discoveredItems: [], results: [])

        coordinator.launchTitleScreenClosed()
        coordinator.launchTitleScreenClosed()
        coordinator.mainPrayerScreenShowing()
        coordinator.mainPrayerScreenShowing()

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine)
        XCTAssertEqual(lines.filter { $0.contains("APP | Launch title screen closed. | INFO") }.count, 1)
        XCTAssertEqual(lines.filter { $0.contains("APP | Main prayer screen showing. | INFO") }.count, 1)
    }

    private struct Fixture {
        let containerURL: URL
        let logStore: SharedDiagnosticsLogStore
        let paths: SharedImportPaths

        @MainActor
        static func make() throws -> Fixture {
            SharedInboxScanCoordinator.resetLaunchGuardsForTesting()
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

        @MainActor
        func makeCoordinator(
            discoveredItems: [SharedRecordingDiscoveredItem],
            results: [SharedRecordingImportResult],
            simulatedShareRunner: (any SharedInboxSimulatedShareRunning)? = nil
        ) -> SharedInboxScanCoordinator {
            SharedInboxScanCoordinator(
                inspector: SharedInboxInspector(paths: paths),
                discoveryService: StubDiscovery(items: discoveredItems),
                pipeline: StubPipeline(results: results),
                paths: paths,
                logStore: logStore,
                logger: SharedDiagnosticsLogger(
                    category: "SHARE_INBOX",
                    store: logStore,
                    mirrorToDebugLog: false
                ),
                appLogger: SharedDiagnosticsLogger(
                    category: "APP",
                    store: logStore,
                    mirrorToDebugLog: false
                ),
                importLogger: SharedDiagnosticsLogger(
                    category: "APP_IMPORT",
                    store: logStore,
                    mirrorToDebugLog: false
                ),
                simulatedShareRunner: simulatedShareRunner ?? SharedInboxSimulatedShareRunner(
                    injector: SharedInboxDebugInjector(
                        paths: paths,
                        logger: SharedDiagnosticsLogger(
                            category: "SIM_SHARE",
                            store: logStore,
                            mirrorToDebugLog: false
                        ),
                        bundledAssetURLProvider: { nil }
                    ),
                    discoveryService: StubDiscovery(items: discoveredItems),
                    pipeline: StubPipeline(results: results),
                    simLogger: SharedDiagnosticsLogger(
                        category: "SIM_SHARE",
                        store: logStore,
                        mirrorToDebugLog: false
                    ),
                    importLogger: SharedDiagnosticsLogger(
                        category: "APP_IMPORT",
                        store: logStore,
                        mirrorToDebugLog: false
                    )
                ),
                finalisedRecordingStore: FileBackedFinalisedImportedRecordingStore(
                    indexFileURL: FamilyRosaryPaths.finalisedImportIndexFileURL(
                        baseDirURL: containerURL
                    )
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

@MainActor
private final class StubSimulatedShareRunner: SharedInboxSimulatedShareRunning {
    private(set) var runCount = 0

    func run() async throws -> SharedInboxSimulatedShareRunResult {
        runCount += 1
        return SharedInboxSimulatedShareRunResult(
            importID: "stub",
            stagedAudioPath: "/tmp/stub.m4a",
            receiptPath: "/tmp/receipt.json",
            discoveredItemCount: 0,
            pipelineResult: SharedRecordingImportResult(importID: "stub", status: .failed(message: "stub"))
        )
    }
}
