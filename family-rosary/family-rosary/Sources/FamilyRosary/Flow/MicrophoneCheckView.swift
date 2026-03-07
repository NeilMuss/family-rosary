import SwiftUI

struct MicrophoneCheckView: View {
    @ObservedObject var viewModel: MicrophoneCheckViewModel

    var body: some View {
        VStack(spacing: 24) {
            HStack {
                Button("Back", action: viewModel.onTapBack)
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)

            Spacer()

            Text(viewModel.titleText)
                .font(.system(size: 40, weight: .bold))
                .multilineTextAlignment(.center)

            Text(viewModel.instructionText)
                .font(.system(size: 28, weight: .medium))
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black.opacity(0.08))
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.black)
                        .frame(width: geo.size.width * CGFloat(viewModel.currentLevel))
                }
            }
            .frame(height: 20)
            .padding(.horizontal, 20)

            if let statusText = viewModel.statusText {
                Text(statusText)
                    .font(.system(size: 22, weight: .semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }

            Spacer()

            Button(action: viewModel.onTapStartPraying) {
                Text("Start praying")
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
        .onAppear(perform: viewModel.onAppear)
    }
}
