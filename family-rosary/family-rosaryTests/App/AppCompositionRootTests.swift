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
}
