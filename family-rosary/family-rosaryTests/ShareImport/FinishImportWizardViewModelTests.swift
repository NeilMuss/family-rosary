import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class FinishImportWizardViewModelTests: XCTestCase {
    func testCannotContinueFromPersonStepWithoutSelectionOrValidNewName() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.continueTapped(trimStart: 0, trimEnd: 1)
        XCTAssertEqual(wizard.currentStep, .person)
        XCTAssertFalse(wizard.canContinue)

        wizard.chooseAddNewPartner()
        XCTAssertFalse(wizard.canContinue)

        wizard.updateNewPartnerName("Grandma")
        XCTAssertTrue(wizard.canContinue)
    }

    func testCannotContinueFromAgeStepWithoutValidAge() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        XCTAssertEqual(wizard.currentStep, .age)
        XCTAssertFalse(wizard.canContinue)

        wizard.updateAgeInput("7")
        XCTAssertTrue(wizard.canContinue)
    }

    func testAgeInputSevenProducesAgeSeven() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("7")

        XCTAssertEqual(wizard.age, 7)
        XCTAssertEqual(wizard.draft.ageAtRecording, 7)
        XCTAssertTrue(wizard.canContinue)
    }

    func testAgeInputLettersIsInvalid() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("abc")

        XCTAssertNil(wizard.age)
        XCTAssertFalse(wizard.canContinue)
    }

    func testAgeInputAboveRangeIsInvalid() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("150")

        XCTAssertEqual(wizard.age, 150)
        XCTAssertFalse(wizard.canContinue)
    }

    func testEmptyAgeInputIsInvalid() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("")

        XCTAssertNil(wizard.age)
        XCTAssertFalse(wizard.canContinue)
    }

    func testPrayerSelectionUpdatesDraft() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("7")
        wizard.continueTapped(trimStart: 0, trimEnd: 1)
        wizard.selectPrayer(.gloryBe)

        XCTAssertEqual(wizard.draft.selectedPrayer, .gloryBe)
    }

    func testPartSelectionUpdatesDraft() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("7")
        wizard.continueTapped(trimStart: 0, trimEnd: 1)
        wizard.selectPrayer(.hailMary)
        wizard.selectPart(.hailMaryResponse)

        XCTAssertEqual(wizard.draft.selectedPart, .hailMaryResponse)
    }

    func testFinalSaveUsesExistingSavePathWhenDraftIsComplete() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.selectExistingPartner("dad")
        wizard.updateAgeInput("7")
        wizard.continueTapped(trimStart: 0, trimEnd: 1)
        wizard.selectPrayer(.ourFather)
        wizard.selectPart(.ourFatherLead)

        XCTAssertEqual(wizard.currentStep, .confirm)

        wizard.continueTapped(trimStart: 0.5, trimEnd: 2.5)

        XCTAssertEqual(fixture.savedDraft?.selectedPartnerID, "dad")
        XCTAssertEqual(fixture.savedDraft?.ageAtRecording, 7)
        XCTAssertEqual(fixture.savedDraft?.selectedPrayer, .ourFather)
        XCTAssertEqual(fixture.savedDraft?.selectedPart, .ourFatherLead)
        XCTAssertEqual(fixture.savedTrimStart, 0.5)
        XCTAssertEqual(fixture.savedTrimEnd, 2.5)
    }

    func testAddingNewPartnerPersistsAndSelectsPartnerBeforeAdvancing() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()

        wizard.chooseAddNewPartner()
        wizard.updateNewPartnerName("Grandma")
        wizard.continueTapped(trimStart: 0, trimEnd: 1)

        XCTAssertEqual(wizard.currentStep, .age)
        XCTAssertFalse(wizard.draft.isAddingNewPartner)
        XCTAssertEqual(wizard.draft.selectedPartnerID, "grandma")
        XCTAssertTrue(wizard.availablePartners.contains(PrayerPartner(id: "grandma", displayName: "Grandma")))
        XCTAssertEqual(fixture.finishImportViewModel.selectedPartnerID, "grandma")
    }

    func testAddingNewPartnerRefreshesChooserListImmediately() throws {
        let fixture = try Fixture.make()
        let wizard = fixture.makeWizard()
        let oldRefreshID = wizard.partnerChooserRefreshID

        wizard.chooseAddNewPartner()
        wizard.updateNewPartnerName("Ausra")
        wizard.continueTapped(trimStart: 0, trimEnd: 1)

        XCTAssertTrue(wizard.availablePartners.contains(PrayerPartner(id: "ausra", displayName: "Ausra")))
        XCTAssertEqual(wizard.draft.selectedPartnerID, "ausra")
        XCTAssertNotEqual(wizard.partnerChooserRefreshID, oldRefreshID)
    }

    private final class SaveSpy {
        var draft: FinishImportDraft?
        var trimStart: TimeInterval?
        var trimEnd: TimeInterval?

        func call(draft: FinishImportDraft, trimStart: TimeInterval, trimEnd: TimeInterval) {
            self.draft = draft
            self.trimStart = trimStart
            self.trimEnd = trimEnd
        }
    }

    private struct Fixture {
        let finishImportViewModel: FinishImportViewModel
        let saveSpy: SaveSpy

        var savedDraft: FinishImportDraft? { saveSpy.draft }
        var savedTrimStart: TimeInterval? { saveSpy.trimStart }
        var savedTrimEnd: TimeInterval? { saveSpy.trimEnd }

        @MainActor
        static func make() throws -> Fixture {
            let baseDirURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: baseDirURL, withIntermediateDirectories: true)
            let suiteName = "FinishImportWizardViewModelTests.\(UUID().uuidString)"
            let userDefaults = UserDefaults(suiteName: suiteName)!
            userDefaults.removePersistentDomain(forName: suiteName)
            let pendingStore = FileBackedPendingImportStore(
                indexFileURL: FamilyRosaryPaths.pendingImportIndexFileURL(baseDirURL: baseDirURL)
            )
            let finalisedStore = FileBackedFinalisedImportedRecordingStore(
                indexFileURL: FamilyRosaryPaths.finalisedImportIndexFileURL(baseDirURL: baseDirURL)
            )
            let pendingImport = PendingImport(
                id: "pending",
                importID: "import",
                libraryFileURL: baseDirURL.appendingPathComponent("pending.m4a"),
                originalFilename: "pending.m4a",
                durationSeconds: 12.5,
                importedAtISO8601: "2026-04-13T12:00:00.000Z"
            )
            let saveSpy = SaveSpy()
            let finishImportViewModel = FinishImportViewModel(
                pendingImport: pendingImport,
                partnerStore: UserDefaultsPrayerPartnerStore(userDefaults: userDefaults),
                finalisedStore: finalisedStore,
                pendingStore: pendingStore,
                onDone: {}
            )
            return Fixture(finishImportViewModel: finishImportViewModel, saveSpy: saveSpy)
        }

        @MainActor
        func makeWizard() -> FinishImportWizardViewModel {
            FinishImportWizardViewModel(finishImportViewModel: finishImportViewModel) { draft, trimStart, trimEnd in
                saveSpy.call(draft: draft, trimStart: trimStart, trimEnd: trimEnd)
            }
        }
    }
}
