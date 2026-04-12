import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

protocol ClipboardWriting {
    func write(_ text: String)
}

struct UIPasteboardClipboardWriter: ClipboardWriting {
    func write(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

struct SharedInboxDiagnosticsCopyAction {
    let clipboardWriter: ClipboardWriting

    func copy(logText: String) -> String {
        clipboardWriter.write(logText)
        return logText == "No logs yet." ? "No logs yet." : "Logs copied."
    }
}

struct SharedInboxDiagnosticsView: View {
    @ObservedObject var viewModel: SharedInboxScanCoordinator
    @State private var copyStatusMessage: String?
    private let copyAction: SharedInboxDiagnosticsCopyAction

    init(
        viewModel: SharedInboxScanCoordinator,
        copyAction: SharedInboxDiagnosticsCopyAction = SharedInboxDiagnosticsCopyAction(
            clipboardWriter: UIPasteboardClipboardWriter()
        )
    ) {
        self.viewModel = viewModel
        self.copyAction = copyAction
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Shared Inbox Debug")
                    .font(.headline)

                HStack {
                    Button("Refresh") {
                        viewModel.refresh()
                    }

                    Button("Copy Logs") {
                        copyLogs()
                    }

                    Button("Clear Logs") {
                        viewModel.clearLogs()
                    }
                }
                .font(.caption)

                if let copyStatusMessage {
                    Text(copyStatusMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

                HStack {
                    Button("Run Simulated Share Test") {
                        viewModel.runSimulatedShareTest()
                    }

                    Button("Write Extension Canary (App-Side Emulation)") {
                        viewModel.writeExtensionCanaryEmulation()
                    }
                }
                .font(.caption)

                HStack {
                    Button("Write App Canary") {
                        viewModel.writeAppCanary()
                    }

                    Button("Read Shared Container") {
                        viewModel.readSharedContainer()
                    }
                }
                .font(.caption)

                if let snapshot = viewModel.sharedContainerSnapshot {
                    Text("Shared Container")
                        .font(.subheadline.weight(.semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("appGroup: \(snapshot.appGroupIdentifier)")
                        Text("appGroup missing: \(snapshot.appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "YES" : "NO")")
                        Text("container exists: \(snapshot.containerExists ? "YES" : "NO")")
                        Text(snapshot.containerPath ?? "container path: nil")
                        Text("log exists: \(snapshot.logFileExists ? "YES" : "NO")")
                        Text(snapshot.logFilePath ?? "log file path: nil")
                        Text("inbox exists: \(snapshot.inboxExists ? "YES" : "NO")")
                        Text(snapshot.inboxPath ?? "inbox path: nil")
                    }
                    .font(.system(size: 10, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("Shared Container Files")
                    .font(.subheadline.weight(.semibold))

                if viewModel.sharedContainerEntries.isEmpty {
                    Text("No shared container files listed yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(viewModel.sharedContainerEntries, id: \.self) { entry in
                            Text(entry)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }

                Text("Pending Shared Inbox Items")
                    .font(.subheadline.weight(.semibold))

                if viewModel.items.isEmpty {
                    Text("No pending shared inbox items.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
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
                }

                Text("Shared Diagnostics Log")
                    .font(.subheadline.weight(.semibold))

                ScrollView {
                    Text(viewModel.visibleLogText)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(viewModel.logEntries.isEmpty ? .secondary : .primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .frame(maxHeight: 250)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(10)
        }
        .background(Color.black.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .task {
            viewModel.diagnosticsViewAppeared()
        }
    }

    private func copyLogs() {
        copyStatusMessage = copyAction.copy(logText: viewModel.visibleLogText)
    }
}
