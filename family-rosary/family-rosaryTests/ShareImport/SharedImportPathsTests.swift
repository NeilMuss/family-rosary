import Foundation
import XCTest
@testable import family_rosary

final class SharedImportPathsTests: XCTestCase {
    func testSharedInboxLayoutIsDeterministic() throws {
        let containerURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = SharedImportPaths(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { containerURL }
        )

        let inboxURL = try paths.sharedInboxDirectoryURL()
        let stagedURL = try paths.stagedImportDirectoryURL(importID: "abc123")
        let receiptURL = try paths.receiptURL(importID: "abc123")

        XCTAssertEqual(inboxURL.path, containerURL.appendingPathComponent("SharedInbox", isDirectory: true).path)
        XCTAssertEqual(stagedURL.path, containerURL.appendingPathComponent("SharedInbox/abc123", isDirectory: true).path)
        XCTAssertEqual(receiptURL.path, containerURL.appendingPathComponent("SharedInbox/abc123/receipt.json").path)
    }

    func testNormalizeFilenamePreservesExtension() throws {
        let filename = try SharedImportPaths.normalizeAudioFilename(originalFilename: "My New Recording.M4A")
        XCTAssertEqual(filename, "my_new_recording.m4a")
    }

    func testNormalizeFilenameInfersExtensionFromTypeIdentifier() throws {
        let filename = try SharedImportPaths.normalizeAudioFilename(
            originalFilename: "voice-note",
            fallbackTypeIdentifier: "public.mpeg-4-audio"
        )
        let ext = URL(fileURLWithPath: filename).pathExtension
        XCTAssertEqual(URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent, "voice_note")
        XCTAssertTrue(["m4a", "mp4"].contains(ext), "Unexpected inferred extension: \(ext)")
    }

    func testNormalizeFilenameFailsWhenNoExtensionCanBeInferred() {
        XCTAssertThrowsError(
            try SharedImportPaths.normalizeAudioFilename(
                originalFilename: "voice-note",
                fallbackTypeIdentifier: nil
            )
        ) { error in
            XCTAssertEqual(error as? SharedImportPathsError, .missingFileExtension)
        }
    }

    func testSharedContainerFailsWhenIdentifierMissing() {
        let paths = SharedImportPaths(appGroupIdentifier: "   ", sharedContainerURLProvider: { nil })

        XCTAssertThrowsError(try paths.sharedContainerURL()) { error in
            XCTAssertEqual(error as? SharedImportPathsError, .appGroupIdentifierMissing)
        }
    }

    func testSharedContainerFailsWhenContainerUnavailable() {
        let paths = SharedImportPaths(
            appGroupIdentifier: "group.com.neilmussett.familyrosary",
            sharedContainerURLProvider: { nil }
        )

        XCTAssertThrowsError(try paths.sharedContainerURL()) { error in
            XCTAssertEqual(
                error as? SharedImportPathsError,
                .appGroupContainerUnavailable(appGroupIdentifier: "group.com.neilmussett.familyrosary")
            )
        }
    }
}
