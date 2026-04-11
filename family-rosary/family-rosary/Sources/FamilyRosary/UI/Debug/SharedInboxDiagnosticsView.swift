import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SharedInboxDiagnosticsView: View {
    @ObservedObject var viewModel: SharedInboxScanCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shared Inbox Debug")
                .font(.headline)

            HStack {
                Button("Refresh") {
                    viewModel.refresh()
                }

                Button("Copy Logs") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = viewModel.logEntries.map(\.formattedLine).joined(separator: "\n")
                    #endif
                }

                Button("Clear Logs") {
                    viewModel.clearLogs()
                }
            }
            .font(.caption)

            HStack {
                Button("Clear Shared Inbox") {
                    viewModel.clearSharedInbox()
                }

                Button("Scan Shared Inbox Now") {
                    Task { @MainActor in
                        await viewModel.scanSharedInboxNow()
                    }
                }
            }
            .font(.caption)

            Text("Pending Shared Inbox Items")
                .font(.subheadline.weight(.semibold))

            if viewModel.items.isEmpty {
                Text("No pending shared inbox items.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(viewModel.items) { item in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.stagedFilename ?? item.sourceFilename ?? item.importID)
                            .font(.caption.weight(.semibold))
                        Text("importID: \(item.importID)")
                            .font(.system(size: 11, design: .monospaced))
                        Text("bytes: \(item.byteSize.map(String.init) ?? "unknown")")
                            .font(.system(size: 11, design: .monospaced))
                        Text("exists: \(item.fileExistsAtManifestPath ? "YES" : "NO")")
                            .font(.system(size: 11, design: .monospaced))
                        Text(item.stagedAudioPath ?? item.receiptPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }

            Text("Shared Diagnostics Log")
                .font(.subheadline.weight(.semibold))

            ScrollView {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(viewModel.logEntries.suffix(200)) { entry in
                        Text(entry.formattedLine)
                            .font(.system(size: 10, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .frame(maxHeight: 220)
        }
        .padding(10)
        .background(Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            viewModel.refresh()
        }
    }
}
