import Foundation
import XCTest
@testable import family_rosary

final class SharedImportConfigurationTests: XCTestCase {
    func testResolvedAppGroupIdentifierUsesCentralizedFallbackWhenBundleValueMissing() {
        let configuration = SharedImportConfiguration.fromMainBundle(bundle: Bundle(for: Self.self))

        XCTAssertEqual(configuration.appGroupIdentifier, SharedContainerConfig.appGroupIdentifier)
    }

    func testCentralizedAppGroupIdentifierMatchesExpectedValue() {
        XCTAssertEqual(SharedContainerConfig.appGroupIdentifier, "group.com.neilmussett.familyrosary")
    }
}
