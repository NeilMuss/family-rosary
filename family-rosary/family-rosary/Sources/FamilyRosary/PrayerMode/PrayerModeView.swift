import SwiftUI

struct PrayerModeView: View {
    @ObservedObject var viewModel: PrayerModeViewModel

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VStack(spacing: 20) {
            HStack {
                Spacer()

                Button("End Rosary", action: viewModel.onTapEndRosary)
                    .font(.system(size: 16, weight: .semibold))
                    .buttonStyle(.bordered)
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            Text(viewModel.displayState.sectionTitle)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()

            Text(viewModel.displayState.prayerTitle)
                .font(.system(size: 48, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            if let countText = viewModel.displayState.countText {
                Text(countText)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            if let rolePrompt = viewModel.displayState.rolePrompt {
                Text(rolePrompt)
                    .font(.system(size: 34, weight: .bold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            }

            #if DEBUG
            let showsDebugOverlay = true
            if showsDebugOverlay, let debug = viewModel.prayerDebugState {
                VStack(alignment: .leading, spacing: 3) {
                    Text(debug.modeText)
                    Text(debug.roleText)
                    Text(debug.listenerStateText)
                    Text(debug.micLevelText)
                    Text(debug.didStartSpeakingText)
                    Text(debug.fallbackArmedText)
                    Text(debug.startTimeoutText)
                    Text(debug.silenceText)
                    Text(debug.prayerText)
                }
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .foregroundStyle(.white)
                .padding(8)
                .background(Color.black.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.leading, 12)
                .padding(.bottom, 12)
                .allowsHitTesting(false)
            }
            #endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
