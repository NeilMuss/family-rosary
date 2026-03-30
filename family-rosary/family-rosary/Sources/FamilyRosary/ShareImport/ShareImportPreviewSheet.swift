import SwiftUI

struct ShareImportPreviewSheet: View {
    @ObservedObject var viewModel: ShareImportPreviewViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                if let message = viewModel.errorMessage, message.isEmpty == false {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                if viewModel.items.count == 1, let item = viewModel.items.first {
                    singleItemView(item)
                } else {
                    multipleItemsView
                }

                Spacer()
            }
            .padding()
            .navigationTitle(viewModel.headline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        viewModel.cancel()
                    }
                }
            }
        }
    }

    private func singleItemView(_ item: ShareImportPreviewItem) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(item.filename)
                .font(.headline)
            if let durationText = item.durationText {
                Text("Duration: \(durationText)")
                    .font(.subheadline)
            }
            Text(item.statusMessage)
                .font(.footnote)
                .foregroundStyle(item.isActionable ? Color.secondary : Color.red)

            HStack(spacing: 12) {
                Button("Play Preview") {
                    viewModel.playPreview(importID: item.importID)
                }
                .buttonStyle(.bordered)

                Button("Use This Recording") {
                    viewModel.useRecording(importID: item.importID)
                }
                .buttonStyle(.borderedProminent)
                .disabled(item.isActionable == false)
            }

            Button("Cancel", role: .cancel) {
                viewModel.cancel()
            }
        }
    }

    private var multipleItemsView: some View {
        List {
            ForEach(viewModel.items) { item in
                VStack(alignment: .leading, spacing: 8) {
                    Text(item.filename)
                        .font(.headline)
                    if let durationText = item.durationText {
                        Text("Duration: \(durationText)")
                            .font(.subheadline)
                    }
                    Text(item.statusMessage)
                        .font(.footnote)
                        .foregroundStyle(item.isActionable ? Color.secondary : Color.red)

                    HStack(spacing: 12) {
                        Button("Play") {
                            viewModel.playPreview(importID: item.importID)
                        }
                        .buttonStyle(.bordered)
                        .disabled(item.audioURL == nil)

                        Button("Use") {
                            viewModel.useRecording(importID: item.importID)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(item.isActionable == false)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}
