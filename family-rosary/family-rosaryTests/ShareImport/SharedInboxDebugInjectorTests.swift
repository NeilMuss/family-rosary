import Foundation
import XCTest
@testable import family_rosary

final class SharedInboxDebugInjectorTests: XCTestCase {
    func testInjectorWritesBundledAssetToSharedInbox() throws {
        let fixture = try Fixture.make()
        let sourceURL = try fixture.makeBundledAssetURL(filename: "debug_share_seed.m4a", data: Data("audio".utf8))
        let injector = fixture.makeInjector(sourceURL: sourceURL)

        let result = try injector.injectBundledTestAudio()

        XCTAssertTrue(FileManager.default.fileExists(atPath: result.stagedAudioURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: result.receiptURL.path))
        XCTAssertEqual(result.byteCount, 5)
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

    private struct Fixture {
        let containerURL: URL
        let assetDirectoryURL: URL
        let logStore: SharedDiagnosticsLogStore
        let logger: SharedDiagnosticsLogger
        let paths: SharedImportPaths

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
                logger: SharedDiagnosticsLogger(
                    category: "SHARE_INBOX",
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

        func makeInjector(sourceURL: URL?) -> SharedInboxDebugInjector {
            SharedInboxDebugInjector(
                paths: paths,
                logger: logger,
                bundledAssetURLProvider: { sourceURL }
            )
        }
    }
}
