import SwiftUI

struct SetupView: View {
    private enum ActiveSelector: String, Identifiable {
        case defaultVoice
        case style
        case mode

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: SetupViewModel
    @ObservedObject var sharedInboxScanCoordinator: SharedInboxScanCoordinator
    @StateObject private var recordingPlayer = AudioPlayerViewModel()
    @State private var activeSelector: ActiveSelector?
    @State private var showsSharedVoices = false
    @State private var selectedRecording: FinalisedImportedRecording?
    @State private var recordingPendingDeletion: FinalisedImportedRecording?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Text("Family Rosary")
                .liturgicalHeadline(size: 42, weight: .bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(LiturgicalTheme.textPrimary)
                .padding(.horizontal, 24)
            .padding(.bottom, 6)

            Text("Pray together, even when apart")
                .font(.system(size: 16, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(LiturgicalTheme.textSecondary.opacity(0.6))
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

            VStack(spacing: 0) {
                selectionRow(title: "Default Voice", value: "Default") {
                    activeSelector = .defaultVoice
                }

                rowDivider

                selectionRow(title: "Shared Voices", value: viewModel.sharedVoicesSummary) {
                    viewModel.reloadSharedVoiceRecordings()
                    showsSharedVoices = true
                }

                rowDivider

                selectionRow(title: "Style", value: viewModel.selectedStyle.displayName) {
                    activeSelector = .style
                }

                rowDivider

                selectionRow(title: "Mode", value: viewModel.selectedMode.displayName) {
                    activeSelector = .mode
                }

                rowDivider

                HStack(spacing: 16) {
                    Text("Candle Background")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(LiturgicalTheme.textSecondary)

                    Spacer()

                    Toggle("Candle Background", isOn: Binding(
                        get: { viewModel.isCandleBackgroundEnabled },
                        set: { viewModel.setCandleBackgroundEnabled($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(LiturgicalTheme.accent)
                }
                .frame(height: 52)
                .padding(.horizontal, 24)

                rowDivider
            }
            .background(LiturgicalTheme.backgroundElevated.opacity(0.46))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer(minLength: 34)

            Button(action: viewModel.onTapPray) {
                Text("Pray")
                    .font(.system(size: 38, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 84)
            }
            .buttonStyle(LiturgicalPrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 30)

            #if DEBUG
            DisclosureGroup("Shared Inbox Diagnostics") {
                SharedInboxDiagnosticsView(viewModel: sharedInboxScanCoordinator)
            }
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(LiturgicalTheme.textSecondary)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .liturgicalScreen(showsCandlePlaceholder: true)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedStyle)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedMode)
        .animation(.easeInOut(duration: 0.36), value: viewModel.isCandleBackgroundEnabled)
        .onAppear {
            viewModel.reloadSharedVoiceRecordings()
        }
        .sheet(isPresented: $showsSharedVoices) {
            sharedVoicesSheet
        }
        .confirmationDialog(
            dialogTitle,
            isPresented: Binding(
                get: { activeSelector != nil },
                set: { if $0 == false { activeSelector = nil } }
            ),
            titleVisibility: .visible
        ) {
            switch activeSelector {
            case .defaultVoice:
                Button("Default") {
                    activeSelector = nil
                }
            case .style:
                ForEach(PrayerStyle.allCases) { style in
                    Button(style.displayName) {
                        viewModel.selectedStyle = style
                        activeSelector = nil
                    }
                }
            case .mode:
                ForEach(PrayerMode.allCases) { mode in
                    Button(mode.displayName) {
                        viewModel.selectedMode = mode
                        activeSelector = nil
                    }
                }
            case .none:
                EmptyView()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(LiturgicalTheme.surfaceBorder)
            .frame(height: 1)
            .padding(.leading, 24)
    }

    private var dialogTitle: String {
        switch activeSelector {
        case .defaultVoice:
            return "Default Voice"
        case .style:
            return "Choose Style"
        case .mode:
            return "Choose Mode"
        case .none:
            return ""
        }
    }

    private var sharedVoicesSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                if viewModel.sharedVoiceRecordings.isEmpty {
                    VStack(spacing: 18) {
                        Text("No shared recordings yet.")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(LiturgicalTheme.textPrimary)

                        Button("Add Shared Voice") {
                            showsSharedVoices = false
                            viewModel.showOnboarding()
                        }
                        .buttonStyle(LiturgicalSecondaryButtonStyle())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(viewModel.sharedVoiceRecordings) { recording in
                                Button {
                                    selectedRecording = recording
                                } label: {
                                    HStack(spacing: 14) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(recording.prayerPart.displayTitle)
                                                .font(.system(size: 17, weight: .semibold))
                                                .foregroundStyle(LiturgicalTheme.textPrimary)

                                            Text(recording.partnerDisplayName ?? recording.partnerID)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(LiturgicalTheme.textSecondary)
                                        }

                                        Spacer()

                                        Image(systemName: "ellipsis.circle")
                                            .font(.system(size: 20, weight: .medium))
                                            .foregroundStyle(LiturgicalTheme.textSecondary)
                                    }
                                    .padding(.horizontal, 20)
                                    .frame(minHeight: 62)
                                }
                                .buttonStyle(.plain)

                                rowDivider
                            }
                        }
                    }

                    Button("Add Shared Voice") {
                        showsSharedVoices = false
                        viewModel.showOnboarding()
                    }
                    .buttonStyle(LiturgicalSecondaryButtonStyle())
                    .padding(20)
                }
            }
            .background(LiturgicalTheme.backgroundPrimary)
            .navigationTitle("Shared Voices")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        recordingPlayer.stopPlayback()
                        showsSharedVoices = false
                    }
                }
            }
        }
        .confirmationDialog(
            selectedRecording?.prayerPart.displayTitle ?? "Recording",
            isPresented: Binding(
                get: { selectedRecording != nil },
                set: { if $0 == false { selectedRecording = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let recording = selectedRecording {
                Button("Play Recording") {
                    recordingPlayer.load(url: recording.libraryFileURL)
                    recordingPlayer.play()
                    selectedRecording = nil
                }
                Button("Replace Recording") {
                    selectedRecording = nil
                    showsSharedVoices = false
                    viewModel.showOnboarding()
                }
                Button("Delete Recording", role: .destructive) {
                    recordingPendingDeletion = recording
                    selectedRecording = nil
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(
            "Delete this recording?",
            isPresented: Binding(
                get: { recordingPendingDeletion != nil },
                set: { if $0 == false { recordingPendingDeletion = nil } }
            ),
            presenting: recordingPendingDeletion
        ) { recording in
            Button("Delete Recording", role: .destructive) {
                recordingPlayer.stopPlayback()
                viewModel.deleteRecording(recording)
                recordingPendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {}
        } message: { recording in
            Text("This will remove your voice for '\(recording.prayerPart.displayTitle)'. The default voice will be used instead.")
        }
        // Users can delete or replace individual prayer recordings; fallback to default voice is automatic.
        .preferredColorScheme(.dark)
    }

    private func selectionRow(
        title: String,
        value: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(LiturgicalTheme.textSecondary)

                Spacer(minLength: 12)

                HStack(spacing: 6) {
                    Spacer(minLength: 0)
                    
                    Text(value)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(LiturgicalTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.trailing)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LiturgicalTheme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: 52)
            .padding(.horizontal, 24)
        }
        .buttonStyle(.plain)
    }
}
