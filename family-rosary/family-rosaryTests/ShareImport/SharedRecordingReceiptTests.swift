import Foundation
import XCTest
@testable import family_rosary

final class SharedRecordingReceiptTests: XCTestCase {
    func testCodableRoundTripPreservesFields() throws {
        let receipt = SharedRecordingReceipt(
            importID: "abc123",
            sourceFilename: "Memo Original.m4a",
            normalizedFilename: "memo_original.m4a",
            stagedAudioFilename: "memo_original.m4a",
            sourceTypeIdentifier: "public.mpeg-4-audio",
            byteCount: 4096,
            stagedAtISO8601: "2026-04-11T12:34:56.789Z"
        )

        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(SharedRecordingReceipt.self, from: data)

        XCTAssertEqual(decoded, receipt)
        XCTAssertEqual(decoded.importID, "abc123")
        XCTAssertEqual(decoded.sourceFilename, "Memo Original.m4a")
        XCTAssertEqual(decoded.normalizedFilename, "memo_original.m4a")
        XCTAssertEqual(decoded.stagedAudioFilename, "memo_original.m4a")
        XCTAssertEqual(decoded.sourceTypeIdentifier, "public.mpeg-4-audio")
        XCTAssertEqual(decoded.byteCount, 4096)
        XCTAssertNotNil(decoded.stagedAtDate)
    }
}
