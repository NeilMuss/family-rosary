import Foundation
import XCTest
@testable import family_rosary

final class AudioImportUseCaseTests: XCTestCase {
    func testImportCreatesRawAudioAndUsesExpectedFilenameForEachSlot() throws {
        let baseDir = temporaryBaseDir()
        let useCase = AudioImportUseCase(baseDirURL: { baseDir })

        let slotToToken: [(ImportSlot, String)] = [
            (.apostlesCreed, "apostles_creed"),
            (.ourFatherLead, "our_father_lead"),
            (.ourFatherResponse, "our_father_response"),
            (.hailMaryLead, "hail_lead"),
            (.hailMaryResponse, "hail_response")
        ]

        for (slot, token) in slotToToken {
            let sourceURL = try makeSourceFile(ext: "m4a", content: "sample-\(token)")
            let destinationURL = try useCase.import(sourceURL: sourceURL, personID: "dad", slot: slot)

            XCTAssertTrue(destinationURL.path.contains("/raw_audio/"))
            XCTAssertEqual(destinationURL.lastPathComponent, "dad_\(token).m4a")
            XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        }
    }

    func testImportPreservesSourceExtension() throws {
        let baseDir = temporaryBaseDir()
        let useCase = AudioImportUseCase(baseDirURL: { baseDir })
        let sourceURL = try makeSourceFile(ext: "wav", content: "wave-data")

        let destinationURL = try useCase.import(sourceURL: sourceURL, personID: "dad", slot: .hailMaryLead)

        XCTAssertEqual(destinationURL.pathExtension, "wav")
        XCTAssertEqual(destinationURL.lastPathComponent, "dad_hail_lead.wav")
    }

    func testImportOverwritesExistingDestination() throws {
        let baseDir = temporaryBaseDir()
        let useCase = AudioImportUseCase(baseDirURL: { baseDir })
        let sourceA = try makeSourceFile(ext: "m4a", content: "old")
        let sourceB = try makeSourceFile(ext: "m4a", content: "new")

        let firstDestination = try useCase.import(sourceURL: sourceA, personID: "dad", slot: .apostlesCreed)
        let secondDestination = try useCase.import(sourceURL: sourceB, personID: "dad", slot: .apostlesCreed)

        XCTAssertEqual(firstDestination, secondDestination)
        let data = try Data(contentsOf: secondDestination)
        XCTAssertEqual(String(data: data, encoding: .utf8), "new")
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
