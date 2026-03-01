import XCTest
@testable import family_rosary

final class AudioTrimCacheTests: XCTestCase {
    func testStoresAndRetrievesTrimValue() async {
        let cache = AudioTrimCache()
        let url = URL(fileURLWithPath: "/tmp/test.m4a")
        let trim = TrimRange(startSec: 0.12, endSec: 2.4)

        await cache.set(trim, for: url)

        guard let cached = await cache.get(url) else {
            XCTFail("Expected cached value")
            return
        }
        XCTAssertEqual(cached, trim)
    }

    func testCachesNilTrimValue() async {
        let cache = AudioTrimCache()
        let url = URL(fileURLWithPath: "/tmp/silent.m4a")

        await cache.set(nil, for: url)

        let cached = await cache.get(url)
        XCTAssertNotNil(cached)
        XCTAssertNil(cached!)
    }
}
