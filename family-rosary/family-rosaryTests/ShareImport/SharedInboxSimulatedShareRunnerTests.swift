import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class SharedInboxSimulatedShareRunnerTests: XCTestCase {
    func testRunStagesAndDiscoversInjectedItem() async throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let injector = fixture.makeInjector(sourceURL: sourceURL)
        let discovery = SharedRecordingDiscoveryService(paths: fixture.paths)
        let runner = SharedInboxSimulatedShareRunner(
            injector: injector,
            discoveryService: discovery,
            pipeline: StubPipeline(
                resultProvider: { importID in
                    SharedRecordingImportResult(
                        importID: importID,
                        status: .imported(
                            ImportedRecording(
                                id: "imported-\(importID)",
                                importID: importID,
                                filename: "shared_\(importID)_debug_share_seed.m4a",
                                libraryRelativePath: "imported_shared_audio/shared_\(importID)_debug_share_seed.m4a",
                                durationSeconds: 1,
                                importedAtISO8601: "2026-04-11T12:00:00.000Z"
                            )
                        )
                    )
                }
            ),
            simLogger: fixture.simLogger,
            importLogger: fixture.importLogger
        )

        let result = try await runner.run()

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.stagedAudioPath))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.receiptPath))
        XCTAssertEqual(result.discoveredItemCount, 1)

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("SIM_SHARE | Startup simulated share test beginning. | INFO"))
        XCTAssertTrue(lines.contains("SIM_SHARE | Bundled source file located: debug_share_seed.m4a | INFO"))
        XCTAssertTrue(lines.contains("SIM_SHARE | Temporary import file copy succeeded:"))
        XCTAssertTrue(lines.contains("SIM_SHARE | Shared staging service write succeeded. | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | Import process beginning for partner TEST. | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | Import file confirmed at path:"))
        XCTAssertTrue(lines.contains("partner=TEST"))
        XCTAssertTrue(lines.contains("APP_IMPORT | Import process succeeded for partner TEST. | SUCCESS"))
        XCTAssertTrue(lines.contains("SIM_SHARE | Startup simulated share test succeeded. | SUCCESS"))
    }

    private struct Fixture {
        let containerURL: URL
        let assetDirectoryURL: URL
        let logStore: SharedDiagnosticsLogStore
        let simLogger: SharedDiagnosticsLogger
        let importLogger: SharedDiagnosticsLogger
        let paths: SharedImportPaths

        @MainActor
        static func make() throws -> Fixture {
            let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let assetDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: assetDirectoryURL, withIntermediateDirectories: true)

            let paths = SharedImportPaths(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )
            let logStore = SharedDiagnosticsLogStore(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )

            return Fixture(
                containerURL: containerURL,
                assetDirectoryURL: assetDirectoryURL,
                logStore: logStore,
                simLogger: SharedDiagnosticsLogger(
                    category: "SIM_SHARE",
                    store: logStore,
                    mirrorToDebugLog: false
                ),
                importLogger: SharedDiagnosticsLogger(
                    category: "APP_IMPORT",
                    store: logStore,
                    mirrorToDebugLog: false
                ),
                paths: paths
            )
        }

        func makeBundledAssetURL(filename: String, data: Data) throws -> URL {
            let url = assetDirectoryURL.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            return url
        }

        @MainActor
        func makeInjector(sourceURL: URL) -> SharedInboxDebugInjector {
            SharedInboxDebugInjector(
                paths: paths,
                logger: simLogger,
                bundledAssetURLProvider: { sourceURL }
            )
        }
    }
}

private struct StubPipeline: SharedRecordingImportRunning {
    let resultProvider: (String) -> SharedRecordingImportResult

    func processAllPending() async -> [SharedRecordingImportResult] {
        []
    }

    func process(importID: String) async -> SharedRecordingImportResult {
        resultProvider(importID)
    }
}
