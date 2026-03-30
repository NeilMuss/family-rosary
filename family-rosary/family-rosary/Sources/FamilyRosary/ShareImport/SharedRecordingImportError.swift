import Foundation

enum SharedRecordingImportError: LocalizedError {
    case stagedImportFolderMissing(importID: String)
    case stagedReceiptMissing(importID: String)
    case stagedReceiptUnreadable(importID: String)
    case sharedAudioMissing(importID: String, expectedFilename: String)
    case sharedAudioEmpty(importID: String)
    case sharedAudioUnreadable(importID: String)
    case sharedAudioUndecodable(importID: String)
    case appLibraryCopyFailed(importID: String, underlying: Error)
    case appLibraryRegisterFailed(importID: String, underlying: Error)

    var errorDescription: String? {
        switch self {
        case let .stagedImportFolderMissing(importID):
            return "The staged shared import folder is missing (import \(importID))."
        case let .stagedReceiptMissing(importID):
            return "The staged shared import receipt is missing (import \(importID))."
        case let .stagedReceiptUnreadable(importID):
            return "The staged shared import receipt could not be decoded (import \(importID))."
        case let .sharedAudioMissing(importID, expectedFilename):
            return "The staged shared audio file \(expectedFilename) could not be found (import \(importID))."
        case let .sharedAudioEmpty(importID):
            return "The shared audio file was copied to the app group, but the copy is empty (0 bytes) (import \(importID))."
        case let .sharedAudioUnreadable(importID):
            return "The app could not read the staged shared audio file (import \(importID))."
        case let .sharedAudioUndecodable(importID):
            return "The app could not decode the shared audio file to read its duration (import \(importID))."
        case let .appLibraryCopyFailed(importID, _):
            return "The recording was staged successfully, but the app could not move it into its library (import \(importID))."
        case let .appLibraryRegisterFailed(importID, _):
            return "The recording file was copied, but the app could not register it in the imported recording store (import \(importID))."
        }
    }
}
