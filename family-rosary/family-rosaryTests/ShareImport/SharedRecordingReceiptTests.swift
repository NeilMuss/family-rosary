import Foundation
import XCTest
@testable import family_rosary

final class SharedRecordingReceiptTests: XCTestCase {
    func testReceiptRoundTripEncodeDecode() throws {
        let receipt = SharedRecordingReceipt(
            importID: "import-123",
            sourceFilename: "Memo.m4a",
            normalizedFilename: "memo.m4a",
            stagedAudioFilename: "memo.m4a",
            sourceTypeIdentifier: "public.mpeg-4-audio",
            byteCount: 1024,
            stagedAtISO8601: "2026-03-30T12:34:56.000Z"
        )

        let data = try JSONEncoder().encode(receipt)
        let decoded = try JSONDecoder().decode(SharedRecordingReceipt.self, from: data)

        XCTAssertEqual(decoded, receipt)
    }

    func testReceiptDecodeFailsWhenRequiredFieldIsMissing() throws {
        let json = """
        {
          "importID": "import-123",
          "sourceFilename": "Memo.m4a",
          "normalizedFilename": "memo.m4a",
          "stagedAudioFilename": "memo.m4a",
          "byteCount": 1024
        }
        """
        let data = Data(json.utf8)

        XCTAssertThrowsError(try JSONDecoder().decode(SharedRecordingReceipt.self, from: data))
    }
}
