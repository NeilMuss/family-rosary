import Foundation

struct FinalisedImportedRecording: Codable, Equatable, Identifiable {
    let id: String
    let importID: String
    let partnerID: String
    let partnerDisplayName: String?
    let ageAtRecording: Int
    let prayer: PrayerName
    let prayerPart: AudioRecordingPart
    let libraryFileURL: URL
    let originalFilename: String
    let durationSeconds: Double
    let importedAtISO8601: String
    let finalisedAtISO8601: String
}
