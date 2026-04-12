import Foundation
import Combine

@MainActor
final class FinishImportViewModel: ObservableObject {
    let pendingImport: PendingImport

    @Published var availablePartners: [PrayerPartner]
    @Published var selectedPartnerID: String?
    @Published var isAddingNewPartner = false
    @Published var newPartnerName = ""
    @Published var ageAtRecordingText = ""
    @Published var selectedPrayer: PrayerName? {
        didSet {
            guard let selectedPrayer else {
                selectedPart = nil
                return
            }
            if let selectedPart, selectedPrayer.availableParts.contains(selectedPart) == false {
                self.selectedPart = nil
            }
        }
    }
    @Published var selectedPart: AudioRecordingPart?
    @Published var validationMessages: [String] = []
    @Published var didAttemptSave = false

    private let partnerStore: PrayerPartnerStoring
    private let finalisedStore: FinalisedImportedRecordingStoring
    private let pendingStore: PendingImportStoring
    private let nowProvider: () -> Date
    private let onDone: () -> Void

    init(
        pendingImport: PendingImport,
        partnerStore: PrayerPartnerStoring,
        finalisedStore: FinalisedImportedRecordingStoring,
        pendingStore: PendingImportStoring,
        nowProvider: @escaping () -> Date = Date.init,
        onDone: @escaping () -> Void
    ) {
        self.pendingImport = pendingImport
        self.partnerStore = partnerStore
        self.finalisedStore = finalisedStore
        self.pendingStore = pendingStore
        self.nowProvider = nowProvider
        self.onDone = onDone
        self.availablePartners = partnerStore.all()
    }

    var availableParts: [AudioRecordingPart] {
        selectedPrayer?.availableParts ?? []
    }

    var canSave: Bool {
        currentValidationMessages().isEmpty
    }

    func confirmAddNewPartner() {
        let trimmed = newPartnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else {
            validationMessages = ["Please enter a name for the new partner."]
            return
        }

        let partner = PrayerPartner(
            id: makeUniquePartnerID(from: trimmed, existingPartners: partnerStore.all()),
            displayName: trimmed
        )
        partnerStore.add(partner)
        availablePartners = partnerStore.all()
        selectedPartnerID = partner.id
        isAddingNewPartner = false
        newPartnerName = ""
    }

    func cancelAddNewPartner() {
        isAddingNewPartner = false
        newPartnerName = ""
    }

    func save() {
        didAttemptSave = true
        let messages = currentValidationMessages()
        validationMessages = messages
        guard messages.isEmpty else {
            return
        }

        guard let selectedPartnerID, let selectedPrayer, let selectedPart else {
            return
        }

        guard let ageAtRecording = Int(ageAtRecordingText.trimmingCharacters(in: .whitespacesAndNewlines)), ageAtRecording > 0 else {
            return
        }

        let finalisedAt = nowProvider()
        let recording = FinalisedImportedRecording(
            id: pendingImport.id,
            importID: pendingImport.importID,
            partnerID: selectedPartnerID,
            ageAtRecording: ageAtRecording,
            prayer: selectedPrayer,
            prayerPart: selectedPart,
            libraryFileURL: pendingImport.libraryFileURL,
            originalFilename: pendingImport.originalFilename,
            durationSeconds: pendingImport.durationSeconds,
            importedAtISO8601: pendingImport.importedAtISO8601,
            finalisedAtISO8601: SharedRecordingReceipt.iso8601Formatter.string(from: finalisedAt)
        )

        do {
            try finalisedStore.save(recording)
            try pendingStore.remove(id: pendingImport.id)
            validationMessages = []
            onDone()
        } catch {
            validationMessages = ["The app could not save this imported recording. Please try again."]
        }
    }

    private func currentValidationMessages() -> [String] {
        var messages: [String] = []

        if selectedPartnerID == nil {
            messages.append("Please choose a partner.")
        }

        let trimmedAge = ageAtRecordingText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedAge.isEmpty {
            messages.append("Please enter the age at recording.")
        } else if let age = Int(trimmedAge) {
            if age <= 0 {
                messages.append("Age at recording must be greater than 0.")
            }
        } else {
            messages.append("Please enter the age at recording.")
        }

        if selectedPrayer == nil {
            messages.append("Please choose a prayer.")
        }

        if selectedPart == nil {
            messages.append("Please choose which part of the prayer this recording is.")
        }

        return messages
    }

    private func makeUniquePartnerID(from name: String, existingPartners: [PrayerPartner]) -> String {
        let base = name
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.isEmpty == false }
            .joined(separator: "-")
        let fallbackBase = base.isEmpty ? "partner" : base
        let existingIDs = Set(existingPartners.map(\.id))

        if existingIDs.contains(fallbackBase) == false {
            return fallbackBase
        }

        var suffix = 2
        while existingIDs.contains("\(fallbackBase)-\(suffix)") {
            suffix += 1
        }
        return "\(fallbackBase)-\(suffix)"
    }
}
