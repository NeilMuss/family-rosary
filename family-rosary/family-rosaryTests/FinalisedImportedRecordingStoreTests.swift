import Foundation
import XCTest
@testable import family_rosary

final class FinalisedImportedRecordingStoreTests: XCTestCase {
    func testSaveThenAllReturnsSavedFinalisedRecording() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()
        let recording = fixture.makeRecording(id: "one", importID: "import-one")

        try store.save(recording)

        XCTAssertEqual(try store.all(), [recording])
    }

    func testSaveSameIDReplacesExistingRecord() throws {
        let fixture = Fixture()
        let store = fixture.makeStore()

        try store.save(fixture.makeRecording(id: "same", importID: "import-a"))
        let replacement = fixture.makeRecording(id: "same", importID: "import-b")

        try store.save(replacement)

        XCTAssertEqual(try store.all(), [replacement])
    }

    func testRoundTripPersistenceWorks() throws {
        let fixture = Fixture()
        let recording = fixture.makeRecording(id: "persist", importID: "import-persist")

        try fixture.makeStore().save(recording)

        let reloadedStore = fixture.makeStore()
        XCTAssertEqual(try reloadedStore.all(), [recording])
    }

    private struct Fixture {
        let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)

        func makeStore() -> FileBackedFinalisedImportedRecordingStore {
            FileBackedFinalisedImportedRecordingStore(
                indexFileURL: FamilyRosaryPaths.finalisedImportIndexFileURL(baseDirURL: baseDirURL)
            )
        }

        func makeRecording(id: String, importID: String) -> FinalisedImportedRecording {
            FinalisedImportedRecording(
                id: id,
                importID: importID,
                partnerID: "dad",
                partnerDisplayName: "Dad",
                ageAtRecording: 42,
                prayer: .hailMary,
                prayerPart: .hailMaryLead,
                libraryFileURL: baseDirURL.appendingPathComponent("\(id).m4a"),
                originalFilename: "\(id).m4a",
                durationSeconds: 8.75,
                importedAtISO8601: "2026-04-12T12:00:00.000Z",
                finalisedAtISO8601: "2026-04-12T12:10:00.000Z"
            )
        }
    }
}
