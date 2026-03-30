import Foundation
import XCTest
@testable import family_rosary

final class ShareImportDeepLinkHandlerTests: XCTestCase {
    func testRecognizedHostRouteReturnsTrue() {
        let handler = ShareImportDeepLinkHandler(expectedScheme: "familyrosary")
        let url = URL(string: "familyrosary://share-import?import_id=abc")!
        XCTAssertTrue(handler.recognizes(url))
    }

    func testRecognizedPathRouteReturnsTrue() {
        let handler = ShareImportDeepLinkHandler(expectedScheme: "familyrosary")
        let url = URL(string: "familyrosary:///share-import")!
        XCTAssertTrue(handler.recognizes(url))
    }

    func testMalformedURLDoesNotCrashAndReturnsFalse() {
        let handler = ShareImportDeepLinkHandler(expectedScheme: "familyrosary")
        let url = URL(string: "https://example.com/not-share")!
        XCTAssertFalse(handler.recognizes(url))
    }
}
