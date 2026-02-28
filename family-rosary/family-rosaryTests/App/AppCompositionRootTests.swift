import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class AppCompositionRootTests: XCTestCase {
    func testMakeBaseDirURLProviderReturnsFileURL() {
        let root = AppCompositionRoot()

        let url = root.makeBaseDirURLProvider()()

        XCTAssertTrue(url.isFileURL)
        XCTAssertFalse(url.path.isEmpty)
    }

    func testMakeAudioRecorderClientReturnsAVAudioRecorderClient() {
        let root = AppCompositionRoot()

        let client = root.makeAudioRecorderClient()

        XCTAssertTrue(client is AVAudioRecorderClient)
    }

    func testMakeAudioPlaybackClientReturnsAVAudioPlaybackClient() {
        let root = AppCompositionRoot()

        let client = root.makeAudioPlaybackClient()

        XCTAssertTrue(client is AVAudioPlaybackClient)
    }

    func testMakeAudioImportUseCaseReturnsAudioImportUseCase() {
        let root = AppCompositionRoot()

        let useCase = root.makeAudioImportUseCase()

        XCTAssertTrue(useCase is AudioImportUseCase)
    }

    func testMakeRecordPrayerViewModelStartsInIdlePhase() {
        let root = AppCompositionRoot()

        let viewModel = root.makeRecordPrayerViewModel(
            personID: "dad",
            part: .hailMaryLead,
            promptText: "Say a Hail Mary for Mom.",
            onDone: {}
        )

        XCTAssertEqual(viewModel.phase, .idle)
    }

    func testMakePrayViewModelStartsNotPraying() {
        let root = AppCompositionRoot()

        let viewModel = root.makePrayViewModel()

        XCTAssertFalse(viewModel.isPraying)
        XCTAssertNil(viewModel.errorMessage)
    }

    func testMakeImportAudioViewModelStartsWithDadAndApostlesCreed() {
        let root = AppCompositionRoot()

        let viewModel = root.makeImportAudioViewModel()

        XCTAssertEqual(viewModel.personID, "dad")
        XCTAssertEqual(viewModel.selectedSlot, .apostlesCreed)
        XCTAssertNil(viewModel.lastImportedFilename)
    }
}
