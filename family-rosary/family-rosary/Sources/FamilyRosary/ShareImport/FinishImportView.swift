import SwiftUI

struct FinishImportView: View {
    @StateObject private var viewModel: FinishImportViewModel

    init(viewModel: FinishImportViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if viewModel.totalPendingCount > 1 {
                        Text("Pending import \(viewModel.queuePosition) of \(viewModel.totalPendingCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(viewModel.pendingImport.originalFilename)
                        .font(.headline)
                    if let durationText = Self.durationFormatter.string(from: viewModel.pendingImport.durationSeconds) {
                        Text("Duration: \(durationText)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Partner") {
                    Picker("Partner", selection: $viewModel.selectedPartnerID) {
                        Text("Select a partner").tag(Optional<String>.none)
                        ForEach(viewModel.availablePartners) { partner in
                            Text(partner.displayName).tag(Optional(partner.id))
                        }
                    }

                    Button(viewModel.isAddingNewPartner ? "Adding New Partner" : "Add New Partner") {
                        viewModel.isAddingNewPartner = true
                    }

                    if viewModel.isAddingNewPartner {
                        TextField("Partner name", text: $viewModel.newPartnerName)

                        HStack {
                            Button("Confirm") {
                                viewModel.confirmAddNewPartner()
                            }
                            Button("Cancel", role: .cancel) {
                                viewModel.cancelAddNewPartner()
                            }
                        }
                    }
                }

                Section("Recording Details") {
                    TextField("Age at recording", text: $viewModel.ageAtRecordingText)
                        .keyboardType(.numberPad)

                    Picker("Prayer", selection: $viewModel.selectedPrayer) {
                        Text("Select a prayer").tag(Optional<PrayerName>.none)
                        ForEach(PrayerName.allCases) { prayer in
                            Text(prayer.displayName).tag(Optional(prayer))
                        }
                    }

                    Picker("Prayer Part", selection: $viewModel.selectedPart) {
                        Text("Select a prayer part").tag(Optional<AudioRecordingPart>.none)
                        ForEach(viewModel.availableParts, id: \.self) { part in
                            Text(part.displayTitle).tag(Optional(part))
                        }
                    }
                    .disabled(viewModel.selectedPrayer == nil)
                }

                if viewModel.didAttemptSave, viewModel.validationMessages.isEmpty == false {
                    Section("Please Fix") {
                        ForEach(viewModel.validationMessages, id: \.self) { message in
                            Text(message)
                                .foregroundStyle(.red)
                        }
                    }
                }

                Section {
                    Button("Save") {
                        viewModel.save()
                    }
                    .disabled(viewModel.canSave == false)
                }
            }
            .navigationTitle("Finish Import")
        }
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
