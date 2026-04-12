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
    @State private var selectedReceipt: ReceiptViewerContent?
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
                        Text("latest receipt exists: \(snapshot.latestReceiptExists ? "YES" : "NO")")
                        Text(snapshot.latestReceiptPath ?? "latest receipt path: nil")
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
                    Text("No pending shared inbox items. Successful imports remove the staged SharedInbox folder and its receipt.json after creating a Pending Import.")
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
                                Text("receipt: \(FileManager.default.fileExists(atPath: item.receiptPath) ? item.receiptPath : "<missing>")")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                Text(item.stagedAudioPath ?? item.receiptPath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                                if FileManager.default.fileExists(atPath: item.receiptPath) {
                                    Button("View Receipt") {
                                        selectedReceipt = ReceiptViewerContent(
                                            title: item.stagedFilename ?? item.sourceFilename ?? item.importID,
                                            receiptPath: item.receiptPath,
                                            receiptText: loadReceiptText(from: item.receiptPath)
                                        )
                                    }
                                    .font(.caption)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                        }
                    }
                }

                Text("Latest Shared Inbox Receipt")
                    .font(.subheadline.weight(.semibold))

                if let snapshot = viewModel.sharedContainerSnapshot {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("receipt: \(snapshot.latestReceiptExists ? (snapshot.latestReceiptPath ?? "<missing>") : "<missing>")")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)

                        if snapshot.latestReceiptExists, let latestReceiptPath = snapshot.latestReceiptPath {
                            Button("View Latest Receipt") {
                                selectedReceipt = ReceiptViewerContent(
                                    title: "Latest Shared Inbox Receipt",
                                    receiptPath: latestReceiptPath,
                                    receiptText: loadReceiptText(from: latestReceiptPath)
                                )
                            }
                            .font(.caption)
                        }
                    }
                } else {
                    Text("receipt: <missing>")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text("Finalized Recordings")
                    .font(.subheadline.weight(.semibold))

                if viewModel.finalisedRecordings.isEmpty {
                    Text("No finalized recordings saved yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.finalisedRecordings) { recording in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(recording.partnerName)
                                    .font(.caption.weight(.semibold))
                                Text("age at recording: \(recording.ageAtRecording)")
                                    .font(.system(size: 11, design: .monospaced))
                                Text("prayer: \(recording.prayer)")
                                    .font(.system(size: 11, design: .monospaced))
                                Text("part: \(recording.part)")
                                    .font(.system(size: 11, design: .monospaced))
                                Text("file: \(recording.filename)")
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
        .sheet(item: $selectedReceipt) { receipt in
            ReceiptViewerSheet(
                content: receipt,
                copyAction: copyAction
            )
        }
    }

    private func copyLogs() {
        copyStatusMessage = copyAction.copy(logText: viewModel.visibleLogText)
    }

    private func loadReceiptText(from path: String) -> String {
        (try? String(contentsOfFile: path, encoding: .utf8)) ?? "Failed to read receipt.json"
    }
}

private struct ReceiptViewerContent: Identifiable {
    let id = UUID()
    let title: String
    let receiptPath: String
    let receiptText: String
}

private struct ReceiptViewerSheet: View {
    let content: ReceiptViewerContent
    let copyAction: SharedInboxDiagnosticsCopyAction
    @Environment(\.dismiss) private var dismiss
    @State private var copyStatusMessage: String?

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Copy") {
                        copyStatusMessage = copyAction.copy(logText: content.receiptText)
                    }

                    if let copyStatusMessage {
                        Text(copyStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)

                Text(content.receiptPath)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    Text(content.receiptText)
                        .font(.system(size: 10, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(8)
                }
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding()
            .navigationTitle("Receipt JSON")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
