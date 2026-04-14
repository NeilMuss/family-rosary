import XCTest
@testable import family_rosary

@MainActor
final class ShareExtensionPresentationStateTests: XCTestCase {
    func testSuccessStateTransition() {
        var controller = ShareExtensionPresentationStateController()

        controller.transitionToSuccess()

        XCTAssertEqual(controller.state, .success)
    }

    func testFailureStateTransition() {
        var controller = ShareExtensionPresentationStateController()

        controller.transitionToFailure(message: "Could not import audio")

        XCTAssertEqual(controller.state, .failure(message: "Could not import audio"))
    }
}
