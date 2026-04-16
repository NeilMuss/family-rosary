import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct PrayView: View {
    @StateObject private var prayViewModel: PrayViewModel
    @StateObject private var importViewModel: ImportAudioViewModel

    init(prayViewModel: PrayViewModel, importViewModel: ImportAudioViewModel) {
        _prayViewModel = StateObject(wrappedValue: prayViewModel)
        _importViewModel = StateObject(wrappedValue: importViewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            if let prompt = prayViewModel.currentPrompt {
                VStack(spacing: 8) {
                    Text(prompt.title)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LiturgicalTheme.textPrimary)

                    Text(prompt.text)
                        .font(.system(size: 24, weight: .medium))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(LiturgicalTheme.textSecondary)
                }
                .padding(.horizontal)
                .liturgicalSurface()
                .padding(.horizontal)
            }

            #if DEBUG
            if !prayViewModel.debugLog.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Debug Trace")
                            .font(.caption2)
                            .fontWeight(.semibold)
                        Spacer()
                        Button("Copy") {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = prayViewModel.debugLog.joined(separator: "\n")
                            #endif
                        }
                        .font(.caption2)
                        Button("Clear") {
                            prayViewModel.clearDebugLog()
                        }
                        .font(.caption2)
                    }

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(Array(prayViewModel.debugLog.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(LiturgicalTheme.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .frame(height: 110)
                }
                .padding(8)
                .liturgicalSurface()
                .padding(.horizontal)
            } else if !prayViewModel.debugText.isEmpty {
                Text(prayViewModel.debugText)
                    .font(.caption2)
                    .foregroundStyle(LiturgicalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            #endif

            Text("Family Rosary")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundStyle(LiturgicalTheme.textPrimary)

            if prayViewModel.isPreparingAudio {
                Text("Preparing audio…")
                    .font(.subheadline)
                    .foregroundStyle(LiturgicalTheme.textSecondary)
            }

            HStack(spacing: 12) {
                Button(action: onTapPrimaryButton) {
                    Text(prayViewModel.isPraying ? "Stop" : "Pray")
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                }
                .buttonStyle(LiturgicalPrimaryButtonStyle())

                Button("Import", action: importViewModel.onTapImport)
                    .font(.headline)
                    .frame(height: 72)
                    .padding(.horizontal, 12)
                    .buttonStyle(LiturgicalSecondaryButtonStyle())
            }
            .padding(.horizontal)

            Toggle("Interactive", isOn: $prayViewModel.isInteractive)
                .padding(.horizontal)
                .foregroundStyle(LiturgicalTheme.textSecondary)
                .tint(LiturgicalTheme.accent)

            VStack(spacing: 10) {
                TextField("Person ID", text: $importViewModel.personID)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .liturgicalInput()

                Picker("Slot", selection: $importViewModel.selectedSlot) {
                    ForEach(ImportSlot.allCases) { slot in
                        Text(slot.displayName).tag(slot)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(LiturgicalTheme.backgroundElevated)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
                )
            }
            .padding(.horizontal)
            .foregroundStyle(LiturgicalTheme.textPrimary)

            if let imported = importViewModel.lastImportedFilename, !imported.isEmpty {
                Text("Imported: \(imported)")
                    .font(.footnote)
                    .foregroundStyle(LiturgicalTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage = prayViewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(LiturgicalTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            if let errorMessage = importViewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(LiturgicalTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liturgicalScreen(showsCandlePlaceholder: true)
        .animation(.easeInOut(duration: 0.4), value: prayViewModel.currentPrompt?.title ?? "")
        .animation(.easeInOut(duration: 0.4), value: prayViewModel.isPraying)
        .sheet(isPresented: $importViewModel.isShowingPicker) {
            DocumentPicker(
                onPick: importViewModel.onPickedFile(url:),
                onCancel: importViewModel.onCancelPicker
            )
        }
        .alert("Microphone Access Required", isPresented: $prayViewModel.showMicrophoneDeniedAlert) {
            Button("OK", role: .cancel) {
            }
        } message: {
            Text("Used to detect spoken responses during prayer.")
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
