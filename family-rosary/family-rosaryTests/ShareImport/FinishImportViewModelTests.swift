import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class FinishImportViewModelTests: XCTestCase {
    func testCannotSaveWithoutRequiredFields() throws {
        let fixture = try Fixture.make()
        let pendingImport = fixture.makePendingImport(id: "pending-a", importID: "import-a")
        try fixture.pendingStore.save(pendingImport)
        let viewModel = fixture.makeViewModel(pendingImport: pendingImport)

        viewModel.save()

        XCTAssertEqual(viewModel.validationMessages, [
            "Please choose a partner.",
            "Please enter the age at recording.",
            "Please choose a prayer.",
            "Please choose which part of the prayer this recording is."
        ])
        XCTAssertEqual(try fixture.finalisedStore.all(), [])
    }

    func testAgeMustBeGreaterThanZero() throws {
        let fixture = try Fixture.make()
        let pendingImport = fixture.makePendingImport(id: "pending-b", importID: "import-b")
        let viewModel = fixture.makeViewModel(pendingImport: pendingImport)

        viewModel.selectedPartnerID = "dad"
        viewModel.ageAtRecordingText = "0"
        viewModel.selectedPrayer = .hailMary
        viewModel.selectedPart = .hailMaryLead

        viewModel.save()

        XCTAssertTrue(viewModel.validationMessages.contains("Age at recording must be greater than 0."))
        XCTAssertEqual(try fixture.finalisedStore.all(), [])
    }

    func testAddNewPartnerSelectsIt() throws {
        let fixture = try Fixture.make()
        let viewModel = fixture.makeViewModel(pendingImport: fixture.makePendingImport(id: "pending-c", importID: "import-c"))

        viewModel.isAddingNewPartner = true
        viewModel.newPartnerName = "Grandma"
        viewModel.confirmAddNewPartner()

        XCTAssertEqual(viewModel.selectedPartnerID, "grandma")
        XCTAssertTrue(fixture.partnerStore.all().contains(PrayerPartner(id: "grandma", displayName: "Grandma")))
        XCTAssertFalse(viewModel.isAddingNewPartner)
    }

    func testAddNewPartnerRefreshesPartnerListImmediately() throws {
        let fixture = try Fixture.make()
        let viewModel = fixture.makeViewModel(pendingImport: fixture.makePendingImport(id: "pending-c2", importID: "import-c2"))
        let oldRefreshID = viewModel.partnerPickerRefreshID

        viewModel.isAddingNewPartner = true
        viewModel.newPartnerName = "Grandpa"
        viewModel.confirmAddNewPartner()

        XCTAssertTrue(viewModel.availablePartners.contains(PrayerPartner(id: "grandpa", displayName: "Grandpa")))
        XCTAssertEqual(viewModel.selectedPartnerID, "grandpa")
        XCTAssertNotEqual(viewModel.partnerPickerRefreshID, oldRefreshID)
    }

    func testSaveMovesPendingToFinalised() throws {
        let fixture = try Fixture.make()
        let pendingImport = fixture.makePendingImport(id: "pending-d", importID: "import-d")
        try fixture.pendingStore.save(pendingImport)
        let viewModel = fixture.makeViewModel(pendingImport: pendingImport)

        viewModel.selectedPartnerID = "dad"
        viewModel.ageAtRecordingText = "7"
        viewModel.selectedPrayer = .ourFather
        viewModel.selectedPart = .ourFatherResponse

        viewModel.save()

        XCTAssertTrue(fixture.didCallOnDone)
        XCTAssertEqual(try fixture.pendingStore.all(), [])
        let saved = try XCTUnwrap(try fixture.finalisedStore.all().first)
        XCTAssertEqual(saved.importID, pendingImport.importID)
        XCTAssertEqual(saved.partnerID, "dad")
        XCTAssertEqual(saved.ageAtRecording, 7)
        XCTAssertEqual(saved.prayer, .ourFather)
        XCTAssertEqual(saved.prayerPart, .ourFatherResponse)
        XCTAssertEqual(saved.libraryFileURL, pendingImport.libraryFileURL)
    }

    func testAgeIsStoredPerRecording() throws {
        let fixture = try Fixture.make()
        let firstPending = fixture.makePendingImport(id: "pending-e1", importID: "import-e1")
        let secondPending = fixture.makePendingImport(id: "pending-e2", importID: "import-e2")
        try fixture.pendingStore.save(firstPending)
        try fixture.pendingStore.save(secondPending)

        let firstViewModel = fixture.makeViewModel(pendingImport: firstPending)
        firstViewModel.selectedPartnerID = "dad"
        firstViewModel.ageAtRecordingText = "4"
        firstViewModel.selectedPrayer = .hailMary
        firstViewModel.selectedPart = .hailMaryLead
        firstViewModel.save()

        let secondViewModel = fixture.makeViewModel(pendingImport: secondPending)
        secondViewModel.selectedPartnerID = "dad"
        secondViewModel.ageAtRecordingText = "9"
        secondViewModel.selectedPrayer = .hailMary
        secondViewModel.selectedPart = .hailMaryResponse
        secondViewModel.save()

        let saved = try fixture.finalisedStore.all().sorted { $0.importID < $1.importID }
        XCTAssertEqual(saved.map(\.ageAtRecording), [4, 9])
    }

    private final class DoneSpy {
        var didCall = false
        func call() {
            didCall = true
        }
    }

    private struct Fixture {
        let baseDirURL: URL
        let pendingStore: FileBackedPendingImportStore
        let finalisedStore: FileBackedFinalisedImportedRecordingStore
        let partnerStore: UserDefaultsPrayerPartnerStore
        let doneSpy: DoneSpy

        var didCallOnDone: Bool {
            doneSpy.didCall
        }

        @MainActor
        static func make() throws -> Fixture {
            let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: baseDirURL, withIntermediateDirectories: true)

            let suiteName = "FinishImportViewModelTests.\(UUID().uuidString)"
            let userDefaults = UserDefaults(suiteName: suiteName)!
            userDefaults.removePersistentDomain(forName: suiteName)

            return Fixture(
                baseDirURL: baseDirURL,
                pendingStore: FileBackedPendingImportStore(
                    indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                finalisedStore: FileBackedFinalisedImportedRecordingStore(
                    indexFileURL: FamilyRosaryPaths.finalisedImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                partnerStore: UserDefaultsPrayerPartnerStore(userDefaults: userDefaults),
                doneSpy: DoneSpy()
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

        @MainActor
        func makeViewModel(pendingImport: PendingImport) -> FinishImportViewModel {
            FinishImportViewModel(
                pendingImport: pendingImport,
                partnerStore: partnerStore,
                finalisedStore: finalisedStore,
                pendingStore: pendingStore,
                queuePosition: 1,
                totalPendingCount: 1,
                nowProvider: { Date(timeIntervalSince1970: 100) },
                onDone: doneSpy.call
            )
        }
    }
}
