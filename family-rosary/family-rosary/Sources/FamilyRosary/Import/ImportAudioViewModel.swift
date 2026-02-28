import Foundation
import Combine

@MainActor
final class ImportAudioViewModel: ObservableObject {
    @Published var isShowingPicker = false
    @Published var selectedSlot: ImportSlot = .apostlesCreed
    @Published var personID = "dad"
    @Published var lastImportedFilename: String?
    @Published var errorMessage: String?

    private let importer: AudioImporting

    init(importer: AudioImporting) {
        self.importer = importer
    }

    func onTapImport() {
        errorMessage = nil
        isShowingPicker = true
    }

    func onPickedFile(url: URL) {
        isShowingPicker = false
        errorMessage = nil

        let trimmedPersonID = personID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedPersonID.isEmpty else {
            errorMessage = "Person ID is required."
            return
        }

        do {
            let destination = try importer.import(
                sourceURL: url,
                personID: trimmedPersonID,
                slot: selectedSlot
            )
            personID = trimmedPersonID
            lastImportedFilename = destination.lastPathComponent
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func onCancelPicker() {
        isShowingPicker = false
    }
}
