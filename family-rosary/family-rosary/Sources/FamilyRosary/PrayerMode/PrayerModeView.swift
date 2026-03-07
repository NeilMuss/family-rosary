import SwiftUI

struct PrayerModeView: View {
    @ObservedObject var viewModel: PrayerModeViewModel

    var body: some View {
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

            Text(viewModel.displayState.countText)
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.secondary)

            Text(viewModel.displayState.roleText)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
