import Foundation
import Combine

enum FinishImportStep: Int, CaseIterable {
    case preview
    case person
    case age
    case prayer
    case part
    case confirm

    var title: String {
        switch self {
        case .preview:
            return "Preview"
        case .person:
            return "Who is speaking?"
        case .age:
            return "How old were they?"
        case .prayer:
            return "What prayer is this?"
        case .part:
            return "Which part is this?"
        case .confirm:
            return "Ready to save"
        }
    }
}

struct FinishImportDraft: Equatable {
    var selectedPartnerID: String?
    var newPartnerName: String
    var isAddingNewPartner: Bool
    var ageAtRecording: Int?
    var selectedPrayer: PrayerName?
    var selectedPart: AudioRecordingPart?
}

@MainActor
final class FinishImportWizardViewModel: ObservableObject {
    @Published private(set) var currentStep: FinishImportStep = .preview
    @Published var draft: FinishImportDraft
    @Published var ageInput: String

    let finishImportViewModel: FinishImportViewModel

    private let logger: SharedDiagnosticsLogger?
    private let onSave: (_ draft: FinishImportDraft, _ trimStart: TimeInterval, _ trimEnd: TimeInterval) -> Void

    init(
        finishImportViewModel: FinishImportViewModel,
        onSave: ((_ draft: FinishImportDraft, _ trimStart: TimeInterval, _ trimEnd: TimeInterval) -> Void)? = nil
    ) {
        self.finishImportViewModel = finishImportViewModel
        self.logger = finishImportViewModel.logger
        self.draft = FinishImportDraft(
            selectedPartnerID: finishImportViewModel.selectedPartnerID,
            newPartnerName: finishImportViewModel.newPartnerName,
            isAddingNewPartner: finishImportViewModel.isAddingNewPartner,
            ageAtRecording: Int(finishImportViewModel.ageAtRecordingText),
            selectedPrayer: finishImportViewModel.selectedPrayer,
            selectedPart: finishImportViewModel.selectedPart
        )
        self.ageInput = finishImportViewModel.ageAtRecordingText
        self.onSave = onSave ?? { [weak finishImportViewModel] draft, trimStart, trimEnd in
            guard let finishImportViewModel else { return }
            if draft.isAddingNewPartner {
                finishImportViewModel.isAddingNewPartner = true
                finishImportViewModel.newPartnerName = draft.newPartnerName
                finishImportViewModel.confirmAddNewPartner()
            } else {
                finishImportViewModel.selectedPartnerID = draft.selectedPartnerID
            }
            finishImportViewModel.ageAtRecordingText = draft.ageAtRecording.map(String.init) ?? ""
            finishImportViewModel.selectedPrayer = draft.selectedPrayer
            finishImportViewModel.selectedPart = draft.selectedPart
            finishImportViewModel.save(trimStart: trimStart, trimEnd: trimEnd)
        }
        logStepChanged()
    }

    var stepNumber: Int { currentStep.rawValue + 1 }
    var totalSteps: Int { FinishImportStep.allCases.count }

    var canGoBack: Bool {
        currentStep != .preview
    }

    var canContinue: Bool {
        switch currentStep {
        case .preview:
            return true
        case .person:
            if draft.isAddingNewPartner {
                return draft.newPartnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            }
            return draft.selectedPartnerID != nil
        case .age:
            guard let age else { return false }
            return (0...120).contains(age)
        case .prayer:
            return draft.selectedPrayer != nil
        case .part:
            return draft.selectedPart != nil
        case .confirm:
            return draftIsComplete
        }
    }

    var draftIsComplete: Bool {
        let hasPerson = draft.isAddingNewPartner
            ? draft.newPartnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            : draft.selectedPartnerID != nil
        let hasAge = age.map { (0...120).contains($0) } ?? false
        return hasPerson && hasAge && draft.selectedPrayer != nil && draft.selectedPart != nil
    }

    var age: Int? {
        Int(ageInput)
    }

    var continueButtonTitle: String {
        currentStep == .confirm ? "Save Recording" : "Continue"
    }

    var currentValidationMessage: String? {
        switch currentStep {
        case .preview:
            return nil
        case .person:
            if draft.isAddingNewPartner, draft.newPartnerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return "Enter a name before continuing."
            }
            if draft.selectedPartnerID == nil, draft.isAddingNewPartner == false {
                return "Choose who is speaking."
            }
            return nil
        case .age:
            return canContinue ? nil : "Enter a valid age (0–120)"
        case .prayer:
            return canContinue ? nil : "Choose the prayer."
        case .part:
            return canContinue ? nil : "Choose which part this recording is."
        case .confirm:
            return draftIsComplete ? nil : "Please complete each step before saving."
        }
    }

    var availablePartners: [PrayerPartner] {
        finishImportViewModel.availablePartners
    }

    var availablePrayers: [PrayerName] {
        finishImportViewModel.availablePrayers
    }

    var availableParts: [AudioRecordingPart] {
        draft.selectedPrayer?.availableParts ?? []
    }

    var summaryPartnerName: String {
        if draft.isAddingNewPartner {
            return draft.newPartnerName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return availablePartners.first(where: { $0.id == draft.selectedPartnerID })?.displayName ?? "Not set"
    }

    func goBack() {
        guard canGoBack, let previous = FinishImportStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
        logStepChanged()
    }

    func continueTapped(trimStart: TimeInterval, trimEnd: TimeInterval) {
        guard canContinue else { return }

        if currentStep == .person, draft.isAddingNewPartner {
            logger?.log(
                stage: "FINISH_IMPORT_NEW_PARTNER_NAME_ENTERED",
                event: "INFO",
                detail: "length=\(draft.newPartnerName.trimmingCharacters(in: .whitespacesAndNewlines).count)"
            )
            finishImportViewModel.isAddingNewPartner = true
            finishImportViewModel.newPartnerName = draft.newPartnerName
            guard let savedPartner = finishImportViewModel.confirmAddNewPartner() else {
                return
            }
            draft.isAddingNewPartner = false
            draft.newPartnerName = ""
            draft.selectedPartnerID = savedPartner.id
        }

        if currentStep == .confirm {
            logger?.log(stage: "FINISH_IMPORT_SAVE_TAPPED", event: "INFO")
            onSave(draft, trimStart, trimEnd)
            return
        }

        if let next = FinishImportStep(rawValue: currentStep.rawValue + 1) {
            currentStep = next
            logStepChanged()
        }
    }

    func selectExistingPartner(_ partnerID: String) {
        draft.isAddingNewPartner = false
        draft.newPartnerName = ""
        draft.selectedPartnerID = partnerID
        logger?.log(stage: "FINISH_IMPORT_PARTNER_SELECTED", event: "INFO", detail: "partner=\(partnerID)")
        autoAdvance(from: .person)
    }

    func chooseAddNewPartner() {
        draft.isAddingNewPartner = true
        draft.selectedPartnerID = nil
    }

    func updateNewPartnerName(_ value: String) {
        draft.newPartnerName = value
    }

    func updateAgeInput(_ value: String) {
        let digitsOnly = value.filter(\.isNumber)
        ageInput = digitsOnly
        draft.ageAtRecording = Int(digitsOnly)
        logger?.log(stage: "FINISH_IMPORT_AGE_SET", event: "INFO", detail: "value=\(draft.ageAtRecording.map(String.init) ?? "nil")")
    }

    func selectPrayer(_ prayer: PrayerName) {
        draft.selectedPrayer = prayer
        if let selectedPart = draft.selectedPart, prayer.availableParts.contains(selectedPart) == false {
            draft.selectedPart = nil
        }
        logger?.log(stage: "FINISH_IMPORT_PRAYER_SELECTED", event: "INFO", detail: "prayer=\(prayer.rawValue)")
        autoAdvance(from: .prayer)
    }

    func selectPart(_ part: AudioRecordingPart) {
        draft.selectedPart = part
        logger?.log(stage: "FINISH_IMPORT_PART_SELECTED", event: "INFO", detail: "part=\(part.rawValue)")
        autoAdvance(from: .part)
    }

    private func autoAdvance(from step: FinishImportStep) {
        guard currentStep == step, canContinue else { return }
        continueTapped(trimStart: 0, trimEnd: finishImportViewModel.pendingImport.durationSeconds)
    }

    private func logStepChanged() {
        logger?.log(stage: "FINISH_IMPORT_STEP_CHANGED", event: "INFO", detail: "step=\(String(describing: currentStep))")
    }
}
