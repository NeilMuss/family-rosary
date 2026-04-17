import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @ObservedObject var sharedInboxScanCoordinator: SharedInboxScanCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Text("Family Rosary")
                    .font(.system(size: 42, weight: .bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(LiturgicalTheme.textPrimary)

                pickerSection(title: "Partner") {
                    Picker("Partner", selection: $viewModel.selectedPartnerID) {
                        ForEach(viewModel.availablePartners) { partner in
                            Text(partner.displayName)
                                .tag(partner.id)
                        }
                    }
                }

                pickerSection(title: "Style") {
                    Picker("Style", selection: $viewModel.selectedStyle) {
                        ForEach(PrayerStyle.allCases) { style in
                            Text(style.displayName)
                                .tag(style)
                        }
                    }
                }

                pickerSection(title: "Mode") {
                    Picker("Mode", selection: $viewModel.selectedMode) {
                        ForEach(PrayerMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Atmosphere")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(LiturgicalTheme.textSecondary)

                    Toggle("Candle Background", isOn: Binding(
                        get: { viewModel.isCandleBackgroundEnabled },
                        set: { viewModel.setCandleBackgroundEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(LiturgicalTheme.accent)
                    .foregroundStyle(LiturgicalTheme.textPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .liturgicalSurface()

                Button(action: viewModel.onTapPray) {
                    Text("Pray")
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                }
                .buttonStyle(LiturgicalPrimaryButtonStyle())
                .padding(.horizontal, 24)

                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    DisclosureGroup("Shared Inbox Diagnostics") {
                        SharedInboxDiagnosticsView(viewModel: sharedInboxScanCoordinator)
                    }
                    .font(.system(size: 18, weight: .semibold))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                #endif

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .liturgicalScreen(showsCandlePlaceholder: true)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedPartnerID)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedStyle)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedMode)
        .animation(.easeInOut(duration: 0.36), value: viewModel.isCandleBackgroundEnabled)
    }

    private func pickerSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(LiturgicalTheme.textSecondary)

            content()
                .pickerStyle(.menu)
                .tint(LiturgicalTheme.textPrimary)
                .font(.system(size: 24, weight: .medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 24)
        .liturgicalSurface()
    }
}
