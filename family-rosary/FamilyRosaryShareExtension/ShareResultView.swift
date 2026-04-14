import SwiftUI

struct ShareResultView: View {
    @ObservedObject var viewModel: ShareResultViewModel
    let onDone: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            switch viewModel.state {
            case .processing:
                ProgressView()
                    .controlSize(.large)
                Text("Sending to Family Rosary")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.green)
                Text("Sent to Family Rosary")
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
            case .failure(let message):
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.orange)
                Text(message)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
        .background(Color(.systemBackground))
        .animation(.easeInOut(duration: 0.18), value: viewModel.state)
    }
}
