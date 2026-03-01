import XCTest
@testable import family_rosary

final class PreviewRuntimeTests: XCTestCase {
    func test_isRunningForPreviews_returnsTrueWhenPreviewFlagIsOne() {
        XCTAssertTrue(
            PreviewRuntime.isRunningForPreviews(
                environment: ["XCODE_RUNNING_FOR_PREVIEWS": "1"],
                imageNames: []
            )
        )
    }

    func test_isRunningForPreviews_returnsFalseWhenPreviewFlagMissingOrNotOne() {
        XCTAssertFalse(PreviewRuntime.isRunningForPreviews(environment: [:], imageNames: []))
        XCTAssertFalse(
            PreviewRuntime.isRunningForPreviews(
                environment: ["XCODE_RUNNING_FOR_PREVIEWS": "0"],
                imageNames: []
            )
        )
    }

    func test_isRunningForPreviews_returnsTrueWhenInjectedPreviewImageIsPresent() {
        XCTAssertTrue(
            PreviewRuntime.isRunningForPreviews(
                environment: [:],
                imageNames: ["/Applications/Xcode.app/.../PreviewsAgentExecutorLibrary.dylib"]
            )
        )
    }

    func test_isInjectedByPreviewsExecutor_matchesPreviewAndInjectionMarkers_caseInsensitive() {
        XCTAssertTrue(
            PreviewRuntime.isInjectedByPreviewsExecutor(
                imageNames: ["/tmp/libpreview_runtime.dylib"]
            )
        )
        XCTAssertTrue(
            PreviewRuntime.isInjectedByPreviewsExecutor(
                imageNames: ["/tmp/SomeInjectionHook.dylib"]
            )
        )
        XCTAssertFalse(
            PreviewRuntime.isInjectedByPreviewsExecutor(
                imageNames: ["/usr/lib/libobjc.A.dylib", "/usr/lib/libswiftCore.dylib"]
            )
        )
    }
}
