import XCTest
@testable import family_rosary

@MainActor
final class FamilyRosaryFlowViewModelTests: XCTestCase {
    func test_interactive_mode_routes_to_microphone_check_before_prayer() {
        let viewModel = FamilyRosaryFlowViewModel(root: AppCompositionRoot(isPreviewRuntime: true))

        viewModel.setupViewModel.selectedMode = .interactive
        viewModel.setupViewModel.onTapPray()

        XCTAssertEqual(viewModel.screen, .microphoneCheck)
        XCTAssertNotNil(viewModel.microphoneCheckViewModel)
    }

    func test_automatic_mode_skips_microphone_check() {
        let viewModel = FamilyRosaryFlowViewModel(root: AppCompositionRoot(isPreviewRuntime: true))

        viewModel.setupViewModel.selectedMode = .automatic
        viewModel.setupViewModel.onTapPray()

        XCTAssertEqual(viewModel.screen, .praying)
        XCTAssertNil(viewModel.microphoneCheckViewModel)
        XCTAssertNotNil(viewModel.prayerModeViewModel)
    }
}
