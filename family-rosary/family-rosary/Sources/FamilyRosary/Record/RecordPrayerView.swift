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
                .foregroundStyle(LiturgicalTheme.textSecondary)

            Text(viewModel.promptText)
                .font(.title3)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .foregroundStyle(LiturgicalTheme.textPrimary)
                .liturgicalSurface()
                .padding(.horizontal)

            if case .review = viewModel.phase {
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button("Keep", action: viewModel.onTapKeep)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .buttonStyle(LiturgicalPrimaryButtonStyle())

                        Button("Redo", action: viewModel.onTapRedo)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .buttonStyle(LiturgicalSecondaryButtonStyle())
                    }

                    Button("Replay", action: viewModel.onTapReplay)
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                        .buttonStyle(LiturgicalSecondaryButtonStyle())
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
                .buttonStyle(LiturgicalPrimaryButtonStyle())
                .padding(.horizontal)
            }

            if let errorMessage = viewModel.errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(LiturgicalTheme.error)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liturgicalScreen(showsCandlePlaceholder: true)
        .animation(.easeInOut(duration: 0.4), value: primaryButtonTitle)
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
