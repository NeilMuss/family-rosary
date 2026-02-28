import SwiftUI

struct PrayView: View {
    @StateObject private var prayViewModel: PrayViewModel
    @StateObject private var importViewModel: ImportAudioViewModel

    init(prayViewModel: PrayViewModel, importViewModel: ImportAudioViewModel) {
        _prayViewModel = StateObject(wrappedValue: prayViewModel)
        _importViewModel = StateObject(wrappedValue: importViewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text("Family Rosary")
                .font(.title)
                .fontWeight(.semibold)

            HStack(spacing: 12) {
                Button(action: onTapPrimaryButton) {
                    Text(prayViewModel.isPraying ? "Stop" : "Pray")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                }
                .buttonStyle(.borderedProminent)

                Button("Import", action: importViewModel.onTapImport)
                    .font(.headline)
                    .frame(height: 72)
                    .padding(.horizontal, 12)
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            VStack(spacing: 10) {
                TextField("Person ID", text: $importViewModel.personID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                Picker("Slot", selection: $importViewModel.selectedSlot) {
                    ForEach(ImportSlot.allCases) { slot in
                        Text(slot.displayName).tag(slot)
                    }
                }
                .pickerStyle(.menu)
            }
            .padding(.horizontal)

            if let imported = importViewModel.lastImportedFilename, !imported.isEmpty {
                Text("Imported: \(imported)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage = prayViewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage = importViewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
        .sheet(isPresented: $importViewModel.isShowingPicker) {
            DocumentPicker(
                onPick: importViewModel.onPickedFile(url:),
                onCancel: importViewModel.onCancelPicker
            )
        }
    }

    private func onTapPrimaryButton() {
        if prayViewModel.isPraying {
            prayViewModel.onTapStop()
        } else {
            prayViewModel.onTapPray()
        }
    }
}
