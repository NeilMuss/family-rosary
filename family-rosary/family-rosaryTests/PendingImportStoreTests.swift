import Foundation
import XCTest
@testable import family_rosary

final class PendingImportStoreTests: XCTestCase {
    func testSaveThenAllReturnsSavedPendingImport() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()
        let pendingImport = fixture.makePendingImport(id: "one", importID: "import-one")

        try store.save(pendingImport)

        XCTAssertEqual(try store.all(), [pendingImport])
    }

    func testSaveSameIDReplacesExistingRecord() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()

        try store.save(fixture.makePendingImport(id: "same", importID: "import-a"))
        let replacement = fixture.makePendingImport(id: "same", importID: "import-b")

        try store.save(replacement)

        XCTAssertEqual(try store.all(), [replacement])
    }

    func testRemoveDeletesRecord() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()
        let pendingImport = fixture.makePendingImport(id: "remove", importID: "import-remove")

        try store.save(pendingImport)
        try store.remove(id: pendingImport.id)

        XCTAssertEqual(try store.all(), [])
    }

    func testRoundTripPersistenceWorks() throws {
        let fixture = Fixture()
        let pendingImport = fixture.makePendingImport(id: "persist", importID: "import-persist")

        try fixture.makeStore().save(pendingImport)

        let reloadedStore = fixture.makeStore()
        XCTAssertEqual(try reloadedStore.all(), [pendingImport])
    }

    private struct Fixture {
        let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        func makeStore() -> FileBackedPendingImportStore {
            FileBackedPendingImportStore(
                indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
            )
        }

        func makePendingImport(id: String, importID: String) -> PendingImport {
            PendingImport(
                id: id,
                importID: importID,
                libraryFileURL: baseDirURL.appendingPathComponent("\(id).m4a"),
                originalFilename: "\(id).m4a",
                durationSeconds: 12.5,
                importedAtISO8601: "2026-04-12T12:00:00.000Z"
            )
        }
    }
}
