import SwiftUI

struct FinishImportView: View {
    @StateObject private var viewModel: FinishImportViewModel
    @StateObject private var wizardViewModel: FinishImportWizardViewModel
    @StateObject private var audioPlayerViewModel: AudioPlayerViewModel

    init(viewModel: FinishImportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _wizardViewModel = StateObject(wrappedValue: FinishImportWizardViewModel(finishImportViewModel: viewModel))
        _audioPlayerViewModel = StateObject(wrappedValue: AudioPlayerViewModel(logger: viewModel.logger))
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Finish Import")
                        .font(.largeTitle.weight(.semibold))
                    Text("Step \(wizardViewModel.stepNumber) of \(wizardViewModel.totalSteps)")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    if viewModel.totalPendingCount > 1 {
                        Text("Pending import \(viewModel.queuePosition) of \(viewModel.totalPendingCount)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text(wizardViewModel.currentStep.title)
                            .font(.title2.weight(.semibold))

                        stepContent

                        if let message = wizardViewModel.currentValidationMessage {
                            Text(message)
                                .font(.body)
                                .foregroundStyle(.red)
                        }

                        if wizardViewModel.currentStep == .confirm,
                           viewModel.didAttemptSave,
                           viewModel.validationMessages.isEmpty == false {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.validationMessages, id: \.self) { message in
                                    Text(message)
                                        .foregroundStyle(.red)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: 16) {
                    Button("Back") {
                        wizardViewModel.goBack()
                    }
                    .buttonStyle(.bordered)
                    .disabled(wizardViewModel.canGoBack == false)

                    Button(wizardViewModel.continueButtonTitle) {
                        wizardViewModel.continueTapped(
                            trimStart: audioPlayerViewModel.trimStart,
                            trimEnd: audioPlayerViewModel.trimEnd
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(wizardViewModel.canContinue == false)
                }
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                audioPlayerViewModel.load(url: viewModel.pendingImport.libraryFileURL)
            }
            .onDisappear {
                audioPlayerViewModel.pause()
            }
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch wizardViewModel.currentStep {
        case .preview:
            previewStep
        case .person:
            personStep
        case .age:
            ageStep
        case .prayer:
            prayerStep
        case .part:
            partStep
        case .confirm:
            confirmStep
        }
    }

    private var previewStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(viewModel.pendingImport.originalFilename)
                .font(.title3.weight(.medium))
            if let durationText = Self.durationFormatter.string(from: audioPlayerViewModel.duration), audioPlayerViewModel.duration > 0 {
                Text("Duration: \(durationText)")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage = audioPlayerViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            } else {
                HStack(spacing: 16) {
                    Button(audioPlayerViewModel.isPlaying ? "Pause" : "Play") {
                        audioPlayerViewModel.togglePlay()
                    }
                    .buttonStyle(.borderedProminent)

                    Text("\(Self.clockFormatter.string(from: audioPlayerViewModel.currentTime) ?? "0:00") / \(Self.clockFormatter.string(from: audioPlayerViewModel.duration) ?? "0:00")")
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                trimRow(
                    title: "Start",
                    value: audioPlayerViewModel.trimStart,
                    onDecrement: audioPlayerViewModel.decrementTrimStart,
                    onIncrement: audioPlayerViewModel.incrementTrimStart
                )
                trimRow(
                    title: "End",
                    value: audioPlayerViewModel.trimEnd,
                    onDecrement: audioPlayerViewModel.decrementTrimEnd,
                    onIncrement: audioPlayerViewModel.incrementTrimEnd
                )
            }
        }
    }

    private var personStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(wizardViewModel.availablePartners) { partner in
                largeChoiceButton(
                    title: partner.displayName,
                    isSelected: wizardViewModel.draft.selectedPartnerID == partner.id && wizardViewModel.draft.isAddingNewPartner == false
                ) {
                    wizardViewModel.selectExistingPartner(partner.id)
                }
            }

            largeChoiceButton(
                title: "Add new person",
                isSelected: wizardViewModel.draft.isAddingNewPartner
            ) {
                wizardViewModel.chooseAddNewPartner()
            }

            if wizardViewModel.draft.isAddingNewPartner {
                TextField(
                    "Enter name",
                    text: Binding(
                        get: { wizardViewModel.draft.newPartnerName },
                        set: { wizardViewModel.updateNewPartnerName($0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .font(.title3)
            }
        }
        .id(viewModel.partnerPickerRefreshID)
    }

    private var ageStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Use the buttons to choose their age.")
                .font(.body)
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button("-") {
                    wizardViewModel.decrementAge()
                }
                .buttonStyle(.bordered)
                .font(.largeTitle)

                Text(wizardViewModel.draft.ageAtRecording.map(String.init) ?? "--")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .frame(minWidth: 100)

                Button("+") {
                    wizardViewModel.incrementAge()
                }
                .buttonStyle(.borderedProminent)
                .font(.largeTitle)
            }
        }
    }

    private var prayerStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(wizardViewModel.availablePrayers) { prayer in
                largeChoiceButton(
                    title: prayer.displayName,
                    isSelected: wizardViewModel.draft.selectedPrayer == prayer
                ) {
                    wizardViewModel.selectPrayer(prayer)
                }
            }
        }
    }

    private var partStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(wizardViewModel.availableParts, id: \.self) { part in
                largeChoiceButton(
                    title: part.displayTitle,
                    isSelected: wizardViewModel.draft.selectedPart == part
                ) {
                    wizardViewModel.selectPart(part)
                }
            }
        }
    }

    private var confirmStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            summaryRow(label: "Person", value: wizardViewModel.summaryPartnerName)
            summaryRow(label: "Age", value: wizardViewModel.draft.ageAtRecording.map(String.init) ?? "Not set")
            summaryRow(label: "Prayer", value: wizardViewModel.draft.selectedPrayer?.displayName ?? "Not set")
            summaryRow(label: "Part", value: wizardViewModel.draft.selectedPart?.displayTitle ?? "Not set")
            summaryRow(label: "Filename", value: viewModel.pendingImport.originalFilename)
        }
    }

    private func trimRow(
        title: String,
        value: TimeInterval,
        onDecrement: @escaping () -> Void,
        onIncrement: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(title)
                .font(.title3)
            Spacer()
            Button("-") { onDecrement() }
                .buttonStyle(.bordered)
            Text(Self.secondsFormatter(value))
                .font(.title3.monospacedDigit())
                .frame(minWidth: 70)
            Button("+") { onIncrement() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func largeChoiceButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.title3.weight(.medium))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(isSelected ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private func summaryRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static let clockFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()

    private static func secondsFormatter(_ value: TimeInterval) -> String {
        String(format: "%.1fs", value)
    }
}
