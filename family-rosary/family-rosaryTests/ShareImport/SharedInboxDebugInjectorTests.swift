import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class SharedInboxDebugInjectorTests: XCTestCase {
    func testInjectorUsesSharedAudioStagingServiceForBundledAsset() throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let stagingSpy = SharedAudioStagingSpy()
        let injector = fixture.makeInjector(sourceURL: sourceURL, stagingService: stagingSpy)

        let result = try injector.injectBundledTestAudio()

        XCTAssertEqual(stagingSpy.requests.count, 1)
        XCTAssertEqual(stagingSpy.requests[0].sourceFileURL, sourceURL)
        XCTAssertEqual(stagingSpy.requests[0].sourceFilename, "debug_share_seed.m4a")
        XCTAssertEqual(result.importID, "spy-import")
    }

    func testInjectorWritesBundledAssetToSharedInbox() throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let injector = fixture.makeInjector(sourceURL: sourceURL)

        let result = try injector.injectBundledTestAudio()

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.stagedAudioURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.receiptURL.path))
        XCTAssertEqual(result.receipt.byteCount, 5)
    }

    func testInjectorWritesMatchingReceipt() throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let injector = fixture.makeInjector(sourceURL: sourceURL)

        let result = try injector.injectBundledTestAudio()
        let data = try Data(contentsOf: result.receiptURL)
        let receipt = try JSONDecoder().decode(SharedRecordingReceipt.self, from: data)

        XCTAssertEqual(receipt.importID, result.importID)
        XCTAssertEqual(receipt.sourceFilename, "debug_share_seed.m4a")
        XCTAssertEqual(receipt.stagedAudioFilename, "debug_share_seed.m4a")
        XCTAssertEqual(receipt.byteCount, 5)

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("SIM_SHARE | SOURCE_FOUND | INFO"))
        XCTAssertTrue(lines.contains("SIM_SHARE | COPY_SUCCESS | INFO"))
        XCTAssertTrue(lines.contains("SIM_SHARE | MANIFEST_WRITE_SUCCESS | INFO"))
        XCTAssertTrue(lines.contains("SIM_SHARE | DESTINATION_EXISTS_CONFIRMED | INFO"))
    }

    func testInjectorFailsWhenBundledAssetMissing() throws {
        let fixture = try Fixture.make()
        let injector = fixture.makeInjector(sourceURL: nil)

        XCTAssertThrowsError(try injector.injectBundledTestAudio()) { error in
            XCTAssertEqual(
                error as? SharedInboxDebugInjectorError,
                .bundledAssetMissing(name: "debug_share_seed.m4a")
            )
        }
    }

    func testDiscoveryCanFindInjectedItem() throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let injector = fixture.makeInjector(sourceURL: sourceURL)
        _ = try injector.injectBundledTestAudio()

        let discovery = SharedRecordingDiscoveryService(paths: fixture.paths)
        let items = discovery.discover()

        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].status, .ready)
        XCTAssertEqual(items[0].receipt?.sourceFilename, "debug_share_seed.m4a")
    }

    func testInjectorFailsWithPreciseErrorWhenAppGroupIdentifierIsMissing() throws {
        let fixture = try Fixture.make(appGroupIdentifier: "   ")
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let injector = fixture.makeInjector(sourceURL: sourceURL)

        XCTAssertThrowsError(try injector.injectBundledTestAudio()) { error in
            XCTAssertEqual(error as? SharedImportPathsError, .appGroupIdentifierMissing)
        }
    }

    private struct Fixture {
        let containerURL: URL
        let assetDirectoryURL: URL
        let logStore: SharedDiagnosticsLogStore
        let logger: SharedDiagnosticsLogger
        let paths: SharedImportPaths

        @MainActor
        static func make(appGroupIdentifier: String = "group.com.neilmussett.familyrosary") throws -> Fixture {
            let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            let assetDirectoryURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            try FileManager.default.createDirectory(at: assetDirectoryURL, withIntermediateDirectories: true)

            let paths = SharedImportPaths(
                appGroupIdentifier: appGroupIdentifier,
                sharedContainerURLProvider: { containerURL }
            )
            let logStore = SharedDiagnosticsLogStore(
                appGroupIdentifier: appGroupIdentifier,
                sharedContainerURLProvider: { containerURL }
            )

            return Fixture(
                containerURL: containerURL,
                assetDirectoryURL: assetDirectoryURL,
                logStore: logStore,
                logger: SharedDiagnosticsLogger(
                    category: "SIM_SHARE",
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
        func makeInjector(
            sourceURL: URL?,
            stagingService: (any SharedAudioStaging)? = nil
        ) -> SharedInboxDebugInjector {
            SharedInboxDebugInjector(
                paths: paths,
                logger: logger,
                bundledAssetURLProvider: { sourceURL },
                stagingService: stagingService
            )
        }
    }
}

private final class SharedAudioStagingSpy: SharedAudioStaging {
    private(set) var requests: [SharedAudioStagingRequest] = []

    func stage(_ request: SharedAudioStagingRequest) throws -> SharedAudioStagingResult {
        requests.append(request)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let stagedAudioURL = root.appendingPathComponent("debug_share_seed.m4a")
        let receiptURL = root.appendingPathComponent("receipt.json")
        try Data("audio".utf8).write(to: stagedAudioURL)
        try Data("{}".utf8).write(to: receiptURL)
        return SharedAudioStagingResult(
            importID: "spy-import",
            stagedFolderURL: root,
            receiptURL: receiptURL,
            stagedAudioURL: stagedAudioURL,
            receipt: SharedAudioStagingReceipt(
                importID: "spy-import",
                sourceFilename: request.sourceFilename,
                normalizedFilename: "debug_share_seed.m4a",
                stagedAudioFilename: "debug_share_seed.m4a",
                sourceTypeIdentifier: request.sourceTypeIdentifier,
                byteCount: 5,
                stagedAtISO8601: "2026-04-12T12:00:00.000Z"
            )
        )
    }
}
