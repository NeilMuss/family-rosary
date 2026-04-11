import AudioToolbox
import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class AudioImportUseCaseTests: XCTestCase {
    func testImportUsesDeterministicCanonicalFilenameForEachSlot() async throws {
        let baseDir = temporaryBaseDir()
        let preparer = SpyImportedAudioPreparationService()
        let useCase = AudioImportUseCase(
            baseDirURL: { baseDir },
            audioPreparationService: preparer
        )

        let slotToToken: [(ImportSlot, String)] = [
            (.apostlesCreed, "apostles_creed"),
            (.ourFatherLead, "our_father_lead"),
            (.ourFatherResponse, "our_father_response"),
            (.hailMaryLead, "hail_lead"),
            (.hailMaryResponse, "hail_response")
        ]

        for (slot, token) in slotToToken {
            let sourceURL = try makeSourceFile(ext: "wav", content: "sample-\(token)")
            let destinationURL = try await useCase.import(sourceURL: sourceURL, personID: "dad", slot: slot)

            XCTAssertTrue(destinationURL.path.contains("/raw_audio/"))
            XCTAssertEqual(destinationURL.lastPathComponent, "dad_\(token).m4a")
        }

        XCTAssertEqual(
            preparer.destinationURLs.map(\.lastPathComponent),
            [
                "dad_apostles_creed.m4a",
                "dad_our_father_lead.m4a",
                "dad_our_father_response.m4a",
                "dad_hail_lead.m4a",
                "dad_hail_response.m4a"
            ]
        )
    }

    func testImportReturnsConvertedOutputPath() async throws {
        let baseDir = temporaryBaseDir()
        let preparer = SpyImportedAudioPreparationService()
        let useCase = AudioImportUseCase(
            baseDirURL: { baseDir },
            audioPreparationService: preparer
        )
        let sourceURL = try makeSourceFile(ext: "mp3", content: "voice")

        let destinationURL = try await useCase.import(sourceURL: sourceURL, personID: "dad", slot: .hailMaryLead)

        XCTAssertEqual(destinationURL, preparer.destinationURLs.first)
        XCTAssertEqual(destinationURL.pathExtension, "m4a")
    }

    func testImportOverwritesExistingDeterministicDestinationPath() async throws {
        let baseDir = temporaryBaseDir()
        let preparer = SpyImportedAudioPreparationService()
        let useCase = AudioImportUseCase(
            baseDirURL: { baseDir },
            audioPreparationService: preparer
        )
        let sourceA = try makeSourceFile(ext: "m4a", content: "old")
        let sourceB = try makeSourceFile(ext: "wav", content: "new")

        let firstDestination = try await useCase.import(sourceURL: sourceA, personID: "dad", slot: .apostlesCreed)
        let secondDestination = try await useCase.import(sourceURL: sourceB, personID: "dad", slot: .apostlesCreed)

        XCTAssertEqual(firstDestination, secondDestination)
        XCTAssertEqual(preparer.destinationURLs.map(\.lastPathComponent), ["dad_apostles_creed.m4a", "dad_apostles_creed.m4a"])
    }

    private func temporaryBaseDir() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    private func makeSourceFile(ext: String, content: String) throws -> URL {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
        try Data(content.utf8).write(to: fileURL)
        return fileURL
    }
}

private final class SpyImportedAudioPreparationService: ImportedAudioPreparing {
    private(set) var destinationURLs: [URL] = []

    func prepare(sourceURL: URL, destinationURL: URL) async throws -> PreparedAudioFile {
        _ = sourceURL
        destinationURLs.append(destinationURL)
        try FileManager.default.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("prepared".utf8).write(to: destinationURL)
        return PreparedAudioFile(
            fileURL: destinationURL,
            inspection: AudioAssetInspection(
                pathExtension: "m4a",
                fileSizeBytes: 8,
                durationSeconds: 3.0,
                sampleRate: 24_000,
                channelCount: 1,
                codecFormatID: kAudioFormatMPEG4AAC,
                estimatedBitRate: 48_000
            ),
            strategy: .transcoded
        )
    }
}
