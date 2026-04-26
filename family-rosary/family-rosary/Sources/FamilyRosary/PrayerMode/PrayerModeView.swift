import SwiftUI

struct PrayerModeView: View {
    @ObservedObject var viewModel: PrayerModeViewModel
    @State private var showsIntroGuidance = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CandleVideoBackgroundView(
                    isEnabled: viewModel.isCandleBackgroundEnabled,
                    isPassiveMode: viewModel.shouldShowCandleBackgroundAtFullEffect
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()

                topReadabilityGradient(screenHeight: geometry.size.height)
                    .allowsHitTesting(false)

                bottomReadabilityGradient
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    // Prayer text is constrained to the dark top-safe region so it never competes with the candle flame.
                    prayerTextStack
                        .padding(.top, textSafeZoneTopPadding(for: geometry))
                        .frame(height: textSafeZoneHeight(for: geometry), alignment: .top)

                    Spacer(minLength: 0)

                    bottomControls

                    #if DEBUG
                    DebugLogView()
                        .frame(height: 140)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    #endif
                }
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

    private var prayerTextStack: some View {
        VStack(spacing: 7) {
            Text(viewModel.displayState.sectionTitle)
                .font(.system(size: 15, weight: .semibold))
                .tracking(2.4)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundStyle(sectionLabelColor)

            Text(viewModel.displayState.prayerTitle)
                .liturgicalHeadline(size: 42, weight: .regular)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .foregroundStyle(titleColor)

            if let countText = viewModel.displayState.countText {
                Text(countText)
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(LiturgicalTheme.textSecondary)
            }

            if viewModel.displayState.rolePrompt != nil {
                Text(rolePromptDisplayText)
                    .font(.system(size: rolePromptFontSize, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(guidanceTextColor)
            } else if showsIntroGuidance {
                Text("The app will lead. You respond.")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(guidanceTextColor)
                    .transition(.opacity)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(LiturgicalTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var bottomControls: some View {
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
    }

    private func topReadabilityGradient(screenHeight: CGFloat) -> some View {
        LinearGradient(
            stops: [
                .init(color: Color.black.opacity(0.95), location: 0),
                .init(color: Color.black.opacity(0.9), location: 0.22),
                .init(color: Color.black.opacity(0.66), location: 0.34),
                .init(color: .clear, location: 0.44)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: screenHeight)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private func textSafeZoneTopPadding(for geometry: GeometryProxy) -> CGFloat {
        max(geometry.safeAreaInsets.top + 2, geometry.size.height * 0.02)
    }

    private func textSafeZoneHeight(for geometry: GeometryProxy) -> CGFloat {
        geometry.size.height * 0.3
    }

    private var bottomReadabilityGradient: some View {
        LinearGradient(
            stops: [
                .init(color: .clear, location: 0),
                .init(color: LiturgicalTheme.backgroundPrimary.opacity(0.16), location: 0.38),
                .init(color: Color.black.opacity(0.52), location: 1)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: 280)
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

    private var guidanceTextColor: Color {
        Color(hex: "E4DED2").opacity(0.72)
    }

    private var rolePromptDisplayText: String {
        viewModel.displayState.rolePrompt == "Continuing for you" ? "Continuing" : (viewModel.displayState.rolePrompt ?? "")
    }

    private var rolePromptFontSize: CGFloat {
        if viewModel.displayState.countText != nil {
            return 16
        }
        return viewModel.displayState.rolePrompt == "Continuing for you" ? 18 : 21
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
