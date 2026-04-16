import SwiftUI

struct PrayerModeView: View {
    @ObservedObject var viewModel: PrayerModeViewModel

    var body: some View {
        ZStack {
            CandleVideoBackgroundView(
                isEnabled: viewModel.isCandleBackgroundEnabled,
                isPassiveMode: viewModel.shouldShowCandleBackgroundAtFullEffect
            )

            VStack(spacing: 20) {
                HStack(alignment: .center, spacing: 12) {
                    Toggle("Candle Background", isOn: Binding(
                        get: { viewModel.isCandleBackgroundEnabled },
                        set: { viewModel.setCandleBackgroundEnabled($0) }
                    ))
                    .toggleStyle(.switch)
                    .tint(LiturgicalTheme.accent)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(LiturgicalTheme.textSecondary)

                    Spacer()

                    Button("End Rosary", action: viewModel.onTapEndRosary)
                        .font(.system(size: 16, weight: .semibold))
                        .buttonStyle(LiturgicalSecondaryButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Text(viewModel.displayState.sectionTitle)
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(LiturgicalTheme.textSecondary)

                Spacer()

                Text(viewModel.displayState.prayerTitle)
                    .font(.system(size: 48, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(LiturgicalTheme.textPrimary)

                if let countText = viewModel.displayState.countText {
                    Text(countText)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(LiturgicalTheme.textSecondary)
                }

                if let rolePrompt = viewModel.displayState.rolePrompt {
                    Text(rolePrompt)
                        .font(.system(size: 34, weight: .bold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .foregroundStyle(LiturgicalTheme.accent)
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(LiturgicalTheme.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()

                Button(action: viewModel.onTapPauseResume) {
                    Text(viewModel.pauseButtonTitle)
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                }
                .buttonStyle(LiturgicalPrimaryButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 24)

                #if DEBUG
                DebugLogView()
                    .frame(height: 140)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liturgicalScreen(showsCandlePlaceholder: false)
        .animation(.easeInOut(duration: 0.42), value: viewModel.displayState.sectionTitle)
        .animation(.easeInOut(duration: 0.42), value: viewModel.displayState.prayerTitle)
        .animation(.easeInOut(duration: 0.42), value: viewModel.pauseButtonTitle)
        .animation(.easeInOut(duration: 0.42), value: viewModel.isCandleBackgroundEnabled)
    }
}
