import Foundation

struct PendingImport: Codable, Equatable, Identifiable {
    let id: String
    let importID: String
    let libraryFileURL: URL
    let originalFilename: String
    let durationSeconds: Double
    let importedAtISO8601: String
}
