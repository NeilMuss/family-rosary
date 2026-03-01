import SwiftUI

struct RecordPrayerView: View {
    @StateObject private var viewModel: RecordPrayerViewModel

    init(viewModel: RecordPrayerViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(spacing: 24) {
            Text(viewModel.part.displayTitle)
                .font(.title2)
                .fontWeight(.semibold)

            Text(viewModel.promptText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if case .review = viewModel.phase {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button("Keep", action: viewModel.onTapKeep)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .buttonStyle(.borderedProminent)

                        Button("Redo", action: viewModel.onTapRedo)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .buttonStyle(.bordered)
                    }

                    Button("Replay", action: viewModel.onTapReplay)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(.bordered)
                }
                .padding(.horizontal)
            } else {
                Button(action: viewModel.onTapRecordOrStop) {
                    Text(primaryButtonTitle)
                        .font(.title2)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 72)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }

    private var primaryButtonTitle: String {
        switch viewModel.phase {
        case .idle:
            return "Record"
        case .recording:
            return "Stop"
        case .review:
            return "Record"
        }
    }
}
