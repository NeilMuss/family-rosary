import SwiftUI

struct PrayerModeView: View {
    @ObservedObject var viewModel: PrayerModeViewModel
    @State private var showsIntroGuidance = false

    var body: some View {
        ZStack {
            CandleVideoBackgroundView(
                isEnabled: viewModel.isCandleBackgroundEnabled,
                isPassiveMode: viewModel.shouldShowCandleBackgroundAtFullEffect
            )

            topReadabilityGradient
                .allowsHitTesting(false)

            bottomReadabilityGradient
                .allowsHitTesting(false)

            VStack(spacing: 20) {
                Color.clear
                    .frame(height: 12)

                Text(viewModel.displayState.sectionTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .tracking(2.4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(sectionLabelColor)

                Spacer(minLength: 56)

                Text(viewModel.displayState.prayerTitle)
                    .liturgicalHeadline(size: 48, weight: .regular)
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(titleColor)

                if showsIntroGuidance {
                    Text("The app will lead. You respond.")
                        .font(.system(size: 16, weight: .medium))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .foregroundStyle(LiturgicalTheme.textSecondary.opacity(0.68))
                        .transition(.opacity)
                }

                if let countText = viewModel.displayState.countText {
                    Text(countText)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(LiturgicalTheme.textSecondary)
                }

                if viewModel.displayState.rolePrompt != nil {
                    Text(rolePromptDisplayText)
                        .font(.system(size: rolePromptFontSize, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .foregroundStyle(statusTextColor.opacity(rolePromptOpacity))
                }

                if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(LiturgicalTheme.error)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }

                Spacer()

                VStack(spacing: 10) {
                    Button(action: viewModel.onTapPauseResume) {
                        Text(viewModel.pauseButtonTitle)
                            .font(.system(size: 34, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 78)
                    }
                    .buttonStyle(LiturgicalPrimaryButtonStyle())

                    HStack {
                        Button("End Rosary", action: viewModel.onTapEndRosary)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(LiturgicalTheme.textSecondary.opacity(0.9))
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                            .buttonStyle(.plain)

                        Spacer()

                        Button(action: viewModel.onTapNextPrayerSegment) {
                            Text("Next")
                                .font(.system(size: 16, weight: .semibold))
                                .tracking(0.3)
                                .foregroundStyle(statusTextColor.opacity(0.92))
                                .padding(.vertical, 10)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
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
        .animation(.easeInOut(duration: 0.22), value: showsIntroGuidance)
        .onAppear(perform: scheduleIntroGuidance)
    }

    private var topReadabilityGradient: some View {
        LinearGradient(
            colors: [
                Color.black.opacity(0.82),
                LiturgicalTheme.backgroundPrimary.opacity(0.68),
                LiturgicalTheme.backgroundPrimary.opacity(0.32),
                .clear
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private var bottomReadabilityGradient: some View {
        LinearGradient(
            colors: [
                .clear,
                LiturgicalTheme.backgroundPrimary.opacity(0.18),
                Color.black.opacity(0.58)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .ignoresSafeArea()
    }

    private var sectionLabelColor: Color {
        Color(hex: "E4DED2").opacity(0.66)
    }

    private var titleColor: Color {
        Color(hex: "F5F3EF")
    }

    private var statusTextColor: Color {
        Color(hex: "CDBFA1").opacity(0.78)
    }

    private var rolePromptDisplayText: String {
        viewModel.displayState.rolePrompt == "Continuing for you" ? "Continuing" : (viewModel.displayState.rolePrompt ?? "")
    }

    private var rolePromptFontSize: CGFloat {
        viewModel.displayState.rolePrompt == "Continuing for you" ? 18 : 24
    }

    private var rolePromptOpacity: Double {
        viewModel.displayState.rolePrompt == "Continuing for you" ? 0.72 : 0.78
    }

    private func scheduleIntroGuidance() {
        guard showsIntroGuidance == false else { return }
        // Subtle first-use guidance; fades out automatically to avoid onboarding UI.
        showsIntroGuidance = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.easeInOut(duration: 0.28)) {
                showsIntroGuidance = false
            }
        }
    }
}
