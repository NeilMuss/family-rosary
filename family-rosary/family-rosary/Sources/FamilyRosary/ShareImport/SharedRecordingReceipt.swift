import Foundation

struct SharedRecordingReceipt: Codable, Equatable {
    let importID: String
    let sourceFilename: String
    let normalizedFilename: String
    let stagedAudioFilename: String
    let sourceTypeIdentifier: String?
    let byteCount: Int64
    let stagedAtISO8601: String

    var stagedAtDate: Date? {
        SharedRecordingReceipt.iso8601Formatter.date(from: stagedAtISO8601)
    }

    static let iso8601Formatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
