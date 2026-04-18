import SwiftUI

struct SetupView: View {
    private enum ActiveSelector: String, Identifiable {
        case partner
        case style
        case mode

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: SetupViewModel
    @ObservedObject var sharedInboxScanCoordinator: SharedInboxScanCoordinator
    @State private var activeSelector: ActiveSelector?

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            Text("Family Rosary")
                .font(.system(size: 42, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(LiturgicalTheme.textPrimary)
                .padding(.horizontal, 24)
            .padding(.bottom, 20)

            VStack(spacing: 0) {
                selectionRow(title: "Partner", value: selectedPartnerName) {
                    activeSelector = .partner
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

                Button("Show Share Guide") {
                    viewModel.showOnboarding()
                }
                .font(.system(size: 16, weight: .medium))
                .buttonStyle(.plain)
                .foregroundStyle(LiturgicalTheme.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .padding(.horizontal, 24)
            }
            .background(LiturgicalTheme.backgroundElevated.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            Button(action: viewModel.onTapPray) {
                Text("Pray")
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
            }
            .buttonStyle(LiturgicalPrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 24)

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
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedPartnerID)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedStyle)
        .animation(.easeInOut(duration: 0.36), value: viewModel.selectedMode)
        .animation(.easeInOut(duration: 0.36), value: viewModel.isCandleBackgroundEnabled)
        .confirmationDialog(
            dialogTitle,
            isPresented: Binding(
                get: { activeSelector != nil },
                set: { if $0 == false { activeSelector = nil } }
            ),
            titleVisibility: .visible
        ) {
            switch activeSelector {
            case .partner:
                ForEach(viewModel.availablePartners) { partner in
                    Button(partner.displayName) {
                        viewModel.selectedPartnerID = partner.id
                        activeSelector = nil
                    }
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

    private var selectedPartnerName: String {
        viewModel.availablePartners.first(where: { $0.id == viewModel.selectedPartnerID })?.displayName ?? "Choose"
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(LiturgicalTheme.surfaceBorder)
            .frame(height: 1)
            .padding(.leading, 24)
    }

    private var dialogTitle: String {
        switch activeSelector {
        case .partner:
            return "Choose Partner"
        case .style:
            return "Choose Style"
        case .mode:
            return "Choose Mode"
        case .none:
            return ""
        }
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
