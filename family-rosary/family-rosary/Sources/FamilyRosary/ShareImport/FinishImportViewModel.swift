import Foundation
import Combine

@MainActor
final class FinishImportViewModel: ObservableObject {
    let pendingImport: PendingImport
    let queuePosition: Int
    let totalPendingCount: Int

    @Published var availablePartners: [PrayerPartner]
    @Published var partnerPickerRefreshID = UUID()
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
    private let logger: SharedDiagnosticsLogger?

    init(
        pendingImport: PendingImport,
        partnerStore: PrayerPartnerStoring,
        finalisedStore: FinalisedImportedRecordingStoring,
        pendingStore: PendingImportStoring,
        queuePosition: Int = 1,
        totalPendingCount: Int = 1,
        logger: SharedDiagnosticsLogger? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        onDone: @escaping () -> Void
    ) {
        self.pendingImport = pendingImport
        self.partnerStore = partnerStore
        self.finalisedStore = finalisedStore
        self.pendingStore = pendingStore
        self.queuePosition = queuePosition
        self.totalPendingCount = totalPendingCount
        self.logger = logger
        self.nowProvider = nowProvider
        self.onDone = onDone
        self.availablePartners = partnerStore.all().sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    var availableParts: [AudioRecordingPart] {
        selectedPrayer?.availableParts ?? []
    }

    var availablePrayers: [PrayerName] {
        PrayerName.supportedImportPrayers
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
        logger?.log(stage: "ADD_PARTNER_SAVE_BEGIN", event: "INFO", detail: "partner=\(trimmed)")
        partnerStore.add(partner)
        let reloadedPartners = partnerStore.all().sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        guard let savedPartner = reloadedPartners.first(where: { $0.id == partner.id }) else {
            logger?.log(stage: "FINISH_IMPORT_SAVE_FAIL", event: "FAIL", detail: "error=partner_save_reload_missing id=\(partner.id)")
            validationMessages = ["The app could not save the new partner. Please try again."]
            return
        }
        logger?.log(stage: "ADD_PARTNER_SAVE_SUCCESS", event: "INFO", detail: "partner=\(savedPartner.displayName)")
        logger?.log(stage: "PARTNER_STORE_RELOAD_SUCCESS", event: "INFO", detail: "count=\(reloadedPartners.count)")
        availablePartners = reloadedPartners
        selectedPartnerID = partner.id
        partnerPickerRefreshID = UUID()
        isAddingNewPartner = false
        newPartnerName = ""
        validationMessages.removeAll(where: { $0 == "Please choose a partner." || $0 == "Please enter a name for the new partner." })
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
        guard let selectedPartner = availablePartners.first(where: { $0.id == selectedPartnerID }) else {
            validationMessages = ["Please choose a partner."]
            logger?.log(stage: "FINISH_IMPORT_SAVE_FAIL", event: "FAIL", detail: "error=selected_partner_missing id=\(selectedPartnerID)")
            return
        }

        guard let ageAtRecording = Int(ageAtRecordingText.trimmingCharacters(in: .whitespacesAndNewlines)), ageAtRecording > 0 else {
            return
        }

        logger?.log(
            stage: "FINAL_RECORD_SAVE_BEGIN",
            event: "INFO",
            detail: "importID=\(pendingImport.importID)"
        )

        let finalisedAt = nowProvider()
        let recording = FinalisedImportedRecording(
            id: pendingImport.id,
            importID: pendingImport.importID,
            partnerID: selectedPartnerID,
            partnerDisplayName: selectedPartner.displayName,
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
            let existingRecordings = try finalisedStore.all()
            if existingRecordings.contains(where: { $0.importID == pendingImport.importID }) {
                logger?.log(
                    stage: "FINISH_IMPORT_SAVE_FAIL",
                    event: "FAIL",
                    detail: "error=duplicate importID=\(pendingImport.importID)"
                )
                validationMessages = ["This imported recording was already saved."]
                return
            }

            try finalisedStore.save(recording)
            let reloadedRecordings = try finalisedStore.all()
            guard reloadedRecordings.contains(where: { $0.importID == pendingImport.importID }) else {
                logger?.log(stage: "FINISH_IMPORT_SAVE_FAIL", event: "FAIL", detail: "error=recording_save_reload_missing importID=\(pendingImport.importID)")
                validationMessages = ["The app could not save this imported recording. Please try again."]
                return
            }
            logger?.log(
                stage: "FINAL_RECORD_SAVE_SUCCESS",
                event: "INFO",
                detail: "importID=\(pendingImport.importID) partner=\(selectedPartnerID) prayer=\(selectedPrayer.rawValue)"
            )
            logger?.log(stage: "RECORDING_STORE_RELOAD_SUCCESS", event: "INFO", detail: "count=\(reloadedRecordings.count)")
            try pendingStore.remove(id: pendingImport.id)
            logger?.log(
                stage: "PENDING_IMPORT_REMOVED",
                event: "INFO",
                detail: "importID=\(pendingImport.importID)"
            )
            validationMessages = []
            DispatchQueue.main.async {
                self.logger?.log(stage: "COORDINATOR_REFRESH_BEGIN", event: "INFO")
                NotificationCenter.default.post(name: .sharedPendingImportsDidChange, object: nil)
                self.logger?.log(stage: "COORDINATOR_REFRESH_COMPLETE", event: "INFO")
                self.onDone()
            }
        } catch {
            logger?.log(
                stage: "FINISH_IMPORT_SAVE_FAIL",
                event: "FAIL",
                detail: "error=\(error.localizedDescription)"
            )
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
