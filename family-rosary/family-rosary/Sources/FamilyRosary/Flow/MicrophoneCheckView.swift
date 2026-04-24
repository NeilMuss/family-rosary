import SwiftUI

struct MicrophoneCheckView: View {
    @ObservedObject var viewModel: MicrophoneCheckViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Back", action: viewModel.onTapBack)
                    .font(.system(size: 18, weight: .semibold))
                    .buttonStyle(LiturgicalSecondaryButtonStyle())
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            Text(viewModel.titleText)
                .liturgicalHeadline(size: 40, weight: .bold)
                .multilineTextAlignment(.center)
                .foregroundStyle(LiturgicalTheme.textPrimary)

            Text(viewModel.instructionText)
                .font(.system(size: 28, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(LiturgicalTheme.textSecondary)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LiturgicalTheme.backgroundElevated)
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LiturgicalTheme.accent.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(viewModel.currentLevel))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
                )
            }
            .frame(height: 20)
            .padding(.horizontal, 20)

            if let statusText = viewModel.statusText {
                Text(statusText)
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                    .foregroundStyle(LiturgicalTheme.textPrimary)
            }

            Spacer()

            Button(action: viewModel.onTapStartPraying) {
                Text("Start praying")
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
            }
            .buttonStyle(LiturgicalPrimaryButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liturgicalScreen(showsCandlePlaceholder: true)
        .animation(.easeInOut(duration: 0.36), value: viewModel.currentLevel)
        .onAppear(perform: viewModel.onAppear)
    }
}
