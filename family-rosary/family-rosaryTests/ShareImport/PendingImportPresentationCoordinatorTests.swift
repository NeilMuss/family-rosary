import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PendingImportPresentationCoordinatorTests: XCTestCase {
    func testMultiplePendingImportsAreQueuedDeterministicallyOldestFirst() throws {
        let fixture = try Fixture.make()
        try fixture.pendingStore.save(fixture.makePendingImport(id: "b", importID: "b", importedAt: "2026-04-12T12:02:00.000Z"))
        try fixture.pendingStore.save(fixture.makePendingImport(id: "a", importID: "a", importedAt: "2026-04-12T12:01:00.000Z"))

        let coordinator = fixture.makeCoordinator()
        coordinator.refreshPendingQueue()

        XCTAssertEqual(coordinator.currentPendingImport?.importID, "a")
        XCTAssertEqual(coordinator.pendingQueueCount, 2)
        XCTAssertEqual(coordinator.currentQueuePosition, 1)
    }

    func testHandleIncomingURLPresentsNextPendingImport() async throws {
        let fixture = try Fixture.make()
        let pendingImport = fixture.makePendingImport(id: "a", importID: "a", importedAt: "2026-04-12T12:01:00.000Z")
        try fixture.pendingStore.save(pendingImport)

        let coordinator = fixture.makeCoordinator(
            pipeline: StubPipeline(results: [
                SharedRecordingImportResult(importID: "a", status: .pendingMetadata(pendingImport))
            ])
        )
        coordinator.handleIncomingURL(URL(string: "familyrosary://share-import")!)
        await Task.yield()

        XCTAssertEqual(coordinator.currentPendingImport?.importID, "a")

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("APP_IMPORT | PENDING_IMPORT_CREATED | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | FINISH_IMPORT_PRESENTED | INFO"))
    }

    func testSaveFinalizesOneItemAndAdvancesToNext() throws {
        let fixture = try Fixture.make()
        let firstPending = fixture.makePendingImport(id: "first", importID: "first", importedAt: "2026-04-12T12:01:00.000Z")
        let secondPending = fixture.makePendingImport(id: "second", importID: "second", importedAt: "2026-04-12T12:02:00.000Z")
        try fixture.pendingStore.save(firstPending)
        try fixture.pendingStore.save(secondPending)

        let coordinator = fixture.makeCoordinator()
        coordinator.refreshPendingQueue()

        let viewModel = FinishImportViewModel(
            pendingImport: firstPending,
            partnerStore: fixture.partnerStore,
            finalisedStore: fixture.finalisedStore,
            pendingStore: fixture.pendingStore,
            queuePosition: coordinator.currentQueuePosition,
            totalPendingCount: coordinator.pendingQueueCount,
            logger: fixture.logger,
            nowProvider: { Date(timeIntervalSince1970: 100) },
            onDone: {
                coordinator.finishImportCompleted()
            }
        )
        viewModel.selectedPartnerID = "dad"
        viewModel.ageAtRecordingText = "8"
        viewModel.selectedPrayer = .hailMary
        viewModel.selectedPart = .hailMaryLead

        viewModel.save()

        XCTAssertEqual(coordinator.currentPendingImport?.importID, "second")
        XCTAssertEqual(try fixture.pendingStore.all().map(\.importID), ["second"])
        XCTAssertEqual(try fixture.finalisedStore.all().map(\.importID), ["first"])

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("APP_IMPORT | FINISH_IMPORT_SAVE_BEGIN | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | FINISH_IMPORT_SAVE_SUCCESS | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | PENDING_IMPORT_REMOVED | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | NEXT_PENDING_IMPORT_PRESENTED | INFO"))
    }

    private struct Fixture {
        let baseDirURL: URL
        let containerURL: URL
        let logStore: SharedDiagnosticsLogStore
        let logger: SharedDiagnosticsLogger
        let pendingStore: FileBackedPendingImportStore
        let finalisedStore: FileBackedFinalisedImportedRecordingStore
        let partnerStore: UserDefaultsPrayerPartnerStore

        @MainActor
        static func make() throws -> Fixture {
            let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: baseDirURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)

            let suiteName = "PendingImportPresentationCoordinatorTests.\(UUID().uuidString)"
            let userDefaults = UserDefaults(suiteName: suiteName)!
            userDefaults.removePersistentDomain(forName: suiteName)
            let logStore = SharedDiagnosticsLogStore(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )

            return Fixture(
                baseDirURL: baseDirURL,
                containerURL: containerURL,
                logStore: logStore,
                logger: SharedDiagnosticsLogger(category: "APP_IMPORT", store: logStore, mirrorToDebugLog: false),
                pendingStore: FileBackedPendingImportStore(
                    indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                finalisedStore: FileBackedFinalisedImportedRecordingStore(
                    indexFileURL: FamilyRosaryPaths.finalisedImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                partnerStore: UserDefaultsPrayerPartnerStore(userDefaults: userDefaults)
            )
        }

        @MainActor
        func makeCoordinator(pipeline: SharedRecordingImportRunning = StubPipeline(results: [])) -> PendingImportPresentationCoordinator {
            PendingImportPresentationCoordinator(
                pendingStore: pendingStore,
                pipeline: pipeline,
                deepLinkHandler: ShareImportDeepLinkHandler(expectedScheme: "familyrosary"),
                logger: logger
            )
        }

        func makePendingImport(id: String, importID: String, importedAt: String) -> PendingImport {
            PendingImport(
                id: id,
                importID: importID,
                libraryFileURL: baseDirURL.appendingPathComponent("\(id).m4a"),
                originalFilename: "\(id).m4a",
                durationSeconds: 4,
                importedAtISO8601: importedAt
            )
        }
    }
}

private struct StubPipeline: SharedRecordingImportRunning {
    let results: [SharedRecordingImportResult]

    func processAllPending() async -> [SharedRecordingImportResult] { results }

    func process(importID: String) async -> SharedRecordingImportResult {
        results.first { $0.importID == importID } ?? SharedRecordingImportResult(importID: importID, status: .failed(message: "missing"))
    }
}
