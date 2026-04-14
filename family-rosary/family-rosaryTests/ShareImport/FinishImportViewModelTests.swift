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

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("APP_IMPORT | ADD_PARTNER_SAVE_BEGIN | INFO | partner=Grandma"))
        XCTAssertTrue(lines.contains("APP_IMPORT | ADD_PARTNER_SAVE_SUCCESS | INFO | partner=Grandma"))
        XCTAssertTrue(lines.contains("APP_IMPORT | PARTNER_STORE_RELOAD_SUCCESS | INFO"))
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

    func testAddNewPartnerReloadsCanonicalPartnerList() throws {
        let fixture = try Fixture.make()
        let reloader = CanonicalPartnerReloader(base: fixture.partnerStore)
        let viewModel = fixture.makeViewModel(
            pendingImport: fixture.makePendingImport(id: "pending-c3", importID: "import-c3"),
            partnerListProvider: reloader.load
        )

        viewModel.isAddingNewPartner = true
        viewModel.newPartnerName = "Grandma"
        let savedPartner = viewModel.confirmAddNewPartner()

        XCTAssertEqual(savedPartner?.id, "grandma")
        XCTAssertGreaterThanOrEqual(reloader.loadCount, 2)
        XCTAssertTrue(viewModel.availablePartners.contains(PrayerPartner(id: "zz-grandma-canonical", displayName: "Grandma (Canonical)")))
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
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertTrue(fixture.didCallOnDone)
        XCTAssertEqual(try fixture.pendingStore.all(), [])
        let saved = try XCTUnwrap(try fixture.finalisedStore.all().first)
        XCTAssertEqual(saved.importID, pendingImport.importID)
        XCTAssertEqual(saved.partnerID, "dad")
        XCTAssertEqual(saved.partnerDisplayName, "Dad")
        XCTAssertEqual(saved.ageAtRecording, 7)
        XCTAssertEqual(saved.prayer, .ourFather)
        XCTAssertEqual(saved.prayerPart, .ourFatherResponse)
        XCTAssertEqual(saved.libraryFileURL, pendingImport.libraryFileURL)

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("APP_IMPORT | FINAL_RECORD_SAVE_BEGIN | INFO | importID=import-d"))
        XCTAssertTrue(lines.contains("APP_IMPORT | FINAL_RECORD_SAVE_SUCCESS | INFO | importID=import-d partner=dad prayer=ourFather"))
        XCTAssertTrue(lines.contains("APP_IMPORT | RECORDING_STORE_RELOAD_SUCCESS | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | PENDING_IMPORT_REMOVED | INFO | importID=import-d"))
        XCTAssertTrue(lines.contains("APP_IMPORT | COORDINATOR_REFRESH_BEGIN | INFO"))
        XCTAssertTrue(lines.contains("APP_IMPORT | COORDINATOR_REFRESH_COMPLETE | INFO"))
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

    func testDuplicateImportIDDoesNotCreateSecondRecordingOrRemovePendingImport() throws {
        let fixture = try Fixture.make()
        let pendingImport = fixture.makePendingImport(id: "pending-f", importID: "import-f")
        try fixture.pendingStore.save(pendingImport)
        try fixture.finalisedStore.save(
            FinalisedImportedRecording(
                id: "existing",
                importID: "import-f",
                partnerID: "dad",
                partnerDisplayName: "Dad",
                ageAtRecording: 6,
                prayer: .hailMary,
                prayerPart: .hailMaryLead,
                libraryFileURL: fixture.baseDirURL.appendingPathComponent("existing.m4a"),
                originalFilename: "existing.m4a",
                durationSeconds: 4,
                importedAtISO8601: "2026-04-12T12:00:00.000Z",
                finalisedAtISO8601: "2026-04-12T12:05:00.000Z"
            )
        )

        let viewModel = fixture.makeViewModel(pendingImport: pendingImport)
        viewModel.selectedPartnerID = "dad"
        viewModel.ageAtRecordingText = "7"
        viewModel.selectedPrayer = .ourFather
        viewModel.selectedPart = .ourFatherResponse

        viewModel.save()
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))

        XCTAssertFalse(fixture.didCallOnDone)
        XCTAssertEqual(try fixture.pendingStore.all().map(\.importID), ["import-f"])
        XCTAssertEqual(try fixture.finalisedStore.all().filter { $0.importID == "import-f" }.count, 1)
        XCTAssertEqual(viewModel.validationMessages, ["This imported recording was already saved."])

        let lines = try fixture.logStore.loadEntries().map(\.formattedLine).joined(separator: "\n")
        XCTAssertTrue(lines.contains("APP_IMPORT | FINISH_IMPORT_SAVE_FAIL | FAIL | error=duplicate importID=import-f"))
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
        let logStore: SharedDiagnosticsLogStore

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
            let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: containerURL, withIntermediateDirectories: true)
            let logStore = SharedDiagnosticsLogStore(
                appGroupIdentifier: "group.com.neilmussett.familyrosary",
                sharedContainerURLProvider: { containerURL }
            )

            return Fixture(
                baseDirURL: baseDirURL,
                pendingStore: FileBackedPendingImportStore(
                    indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                finalisedStore: FileBackedFinalisedImportedRecordingStore(
                    indexFileURL: FamilyRosaryPaths.finalisedImportIndexFileURL(baseDirURL: baseDirURL)
                ),
                partnerStore: UserDefaultsPrayerPartnerStore(userDefaults: userDefaults),
                doneSpy: DoneSpy(),
                logStore: logStore
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
        func makeViewModel(
            pendingImport: PendingImport,
            partnerListProvider: (() -> [PrayerPartner])? = nil
        ) -> FinishImportViewModel {
            FinishImportViewModel(
                pendingImport: pendingImport,
                partnerStore: partnerStore,
                partnerListProvider: partnerListProvider,
                finalisedStore: finalisedStore,
                pendingStore: pendingStore,
                queuePosition: 1,
                totalPendingCount: 1,
                logger: SharedDiagnosticsLogger(category: "APP_IMPORT", store: logStore, mirrorToDebugLog: false),
                nowProvider: { Date(timeIntervalSince1970: 100) },
                onDone: doneSpy.call
            )
        }
    }
}

private final class CanonicalPartnerReloader {
    private let base: UserDefaultsPrayerPartnerStore
    private(set) var loadCount = 0

    init(base: UserDefaultsPrayerPartnerStore) {
        self.base = base
    }

    func load() -> [PrayerPartner] {
        loadCount += 1
        var partners = base.all()
        if partners.contains(where: { $0.id == "grandma" }) {
            partners.append(PrayerPartner(id: "zz-grandma-canonical", displayName: "Grandma (Canonical)"))
        }
        return partners
    }
}
