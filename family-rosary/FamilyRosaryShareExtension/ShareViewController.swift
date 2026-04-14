import Combine
import SwiftUI
import UIKit
import UniformTypeIdentifiers

@MainActor
final class ShareResultViewModel: ObservableObject {
    @Published var state = ShareExtensionPresentationState.processing
}

final class ShareViewController: UIViewController {
    private let sessionID = UUID().uuidString
    private let configuration = SharedImportConfiguration.fromMainBundle()
    private let resultViewModel = ShareResultViewModel()
    private var didStartImport = false
    private var pendingFailureError: NSError?

    private lazy var hostingController = UIHostingController(
        rootView: ShareResultView(
            viewModel: resultViewModel,
            onDone: { [weak self] in
                self?.dismissAfterFailure()
            }
        )
    )

    override func viewDidLoad() {
        super.viewDidLoad()
        embedResultView()
        Task { @MainActor in
            await startImportIfNeeded()
        }
    }

    private func embedResultView() {
        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear
        view = UIView()
        view.backgroundColor = .systemBackground
        view.addSubview(hostingController.view)
        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        hostingController.didMove(toParent: self)
    }

    private func startImportIfNeeded() async {
        guard didStartImport == false else { return }
        didStartImport = true
        await runImport()
    }

    private func runImport() async {
        updateStatus("LOGGING READY", details: [
            "extensionContextPresent": extensionContext == nil ? "NO" : "YES"
        ])

        guard resolveSharedPaths() else {
            presentFailure(message: "Could not import audio")
            return
        }

        guard let extensionContext else {
            presentFailure(message: "Could not import audio")
            return
        }

        let inputItems = extensionContext.inputItems as? [NSExtensionItem] ?? []
        updateStatus("INPUT ITEMS INSPECTED", details: [
            "inputItemCount": String(inputItems.count)
        ])
        guard inputItems.isEmpty == false else {
            presentFailure(message: "Could not import audio")
            return
        }

        updateStatus("ATTACHMENT SEARCH BEGIN")
        let providers = inputItems.flatMap { $0.attachments ?? [] }
        guard providers.isEmpty == false else {
            presentFailure(message: "Could not import audio")
            return
        }

        guard let candidate = firstAudioCandidate(from: providers) else {
            let seenTypes = providers.flatMap(\.registeredTypeIdentifiers).joined(separator: ",")
            updateStatus("FAIL: NO AUDIO PROVIDER", details: [
                "registeredTypeIdentifiers": seenTypes
            ])
            presentFailure(message: "Could not import audio", reason: "Unsupported format")
            return
        }

        updateStatus("ATTACHMENT FOUND", details: [
            "typeIdentifier": candidate.preferredTypeIdentifier,
            "registeredTypeIdentifiers": candidate.registeredTypeIdentifiers.joined(separator: ",")
        ])
        updateStatus("LOAD ITEM BEGIN", details: [
            "typeIdentifier": candidate.preferredTypeIdentifier
        ])

        do {
            let loaded = try await loadAttachment(candidate)
            updateStatus("LOAD ITEM SUCCESS", details: [
                "sourceFilename": loaded.sourceFilename,
                "byteCount": String(loaded.byteCount)
            ])
            await stageLoadedAttachment(loaded, extensionContext: extensionContext)
        } catch let error as ShareImportError {
            updateStatus("FAIL: LOAD ITEM ERROR", details: [
                "reason": error.localizedDescription
            ])
            presentFailure(message: "Could not import audio", reason: userFacingReason(for: error), error: error.asNSError)
        } catch {
            updateStatus("FAIL: LOAD ITEM ERROR", details: [
                "reason": error.localizedDescription
            ])
            presentFailure(message: "Could not import audio", reason: "File unreadable")
        }
    }

    @MainActor
    private func stageLoadedAttachment(
        _ loaded: LoadedShareAttachment,
        extensionContext: NSExtensionContext
    ) async {
        updateStatus("SECURITY SCOPE BEGIN", details: [
            "note": "file already copied to tmp by loadAttachment",
            "tmpPath": loaded.fileURL.path
        ])

        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default,
            allowFallbackToLocalDocuments: false
        )
        let inboxURL: URL
        do {
            inboxURL = try store.inboxURL()
        } catch {
            updateStatus("FAIL: INBOX UNAVAILABLE", details: [
                "reason": error.localizedDescription
            ])
            presentFailure(message: "Could not import audio", reason: "Storage unavailable")
            return
        }

        let importID = UUID().uuidString
        let stagedFolderURL = inboxURL.appendingPathComponent(importID, isDirectory: true)
        let audioFilename = resolveAudioFilename(
            sourceFilename: loaded.sourceFilename,
            sourceExtension: loaded.fileURL.pathExtension,
            sourceTypeIdentifier: loaded.sourceTypeIdentifier
        )
        let stagedAudioURL = stagedFolderURL.appendingPathComponent(audioFilename)
        let receiptURL = stagedFolderURL.appendingPathComponent("receipt.json")

        updateStatus("COPY BEGIN", details: [
            "importID": importID,
            "sourceFilename": loaded.sourceFilename,
            "destinationFilename": audioFilename
        ])

        do {
            try FileManager.default.createDirectory(
                at: stagedFolderURL,
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: loaded.fileURL, to: stagedAudioURL)
        } catch {
            updateStatus("FAIL: COPY FAILED", details: [
                "importID": importID,
                "reason": error.localizedDescription
            ])
            presentFailure(message: "Could not import audio", reason: "File unreadable")
            return
        }

        updateStatus("COPY SUCCESS", details: [
            "importID": importID,
            "byteCount": String(loaded.byteCount)
        ])

        updateStatus("MANIFEST WRITE BEGIN", details: ["importID": importID])

        do {
            let receipt = StagedReceiptPayload(
                importID: importID,
                sourceFilename: loaded.sourceFilename,
                normalizedFilename: audioFilename,
                stagedAudioFilename: audioFilename,
                sourceTypeIdentifier: loaded.sourceTypeIdentifier,
                byteCount: loaded.byteCount,
                stagedAtISO8601: Self.iso8601Formatter.string(from: Date())
            )
            let receiptData = try JSONEncoder().encode(receipt)
            try receiptData.write(to: receiptURL, options: .atomic)
        } catch {
            updateStatus("FAIL: MANIFEST WRITE FAILED", details: [
                "importID": importID,
                "reason": error.localizedDescription
            ])
            presentFailure(message: "Could not import audio")
            return
        }

        updateStatus("MANIFEST WRITE SUCCESS", details: ["importID": importID])

        if let shareImportURL = configuration.makeShareImportURL(importID: importID) {
            openContainingApp(url: shareImportURL)
        } else {
            updateStatus("FAIL: OPEN APP URL INVALID", details: ["importID": importID])
        }

        resultViewModel.state = .success
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_100_000_000)
            extensionContext.completeRequest(returningItems: nil)
        }
    }

    private func presentFailure(message: String, reason: String? = nil, error: NSError? = nil) {
        pendingFailureError = error ?? diagnosticNSError(reason ?? message)
        let renderedMessage = reason.map { "\(message)\n\($0)" } ?? message
        resultViewModel.state = .failure(message: renderedMessage)
    }

    private func dismissAfterFailure() {
        extensionContext?.cancelRequest(withError: pendingFailureError ?? diagnosticNSError("Could not import audio"))
    }

    private func openContainingApp(url: URL) {
        updateStatus("OPEN APP BEGIN", details: ["url": url.absoluteString])

        let selector = sel_registerName("openURL:")
        var responder: UIResponder? = self
        while let currentResponder = responder {
            if currentResponder.responds(to: selector) {
                _ = currentResponder.perform(selector, with: url)
                updateStatus("OPEN APP SUCCESS", details: ["url": url.absoluteString])
                return
            }
            responder = currentResponder.next
        }

        updateStatus("FAIL: OPEN APP FAILED", details: ["url": url.absoluteString])
    }

    private func resolveAudioFilename(
        sourceFilename: String,
        sourceExtension: String,
        sourceTypeIdentifier: String
    ) -> String {
        let ext = sourceExtension.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedExt: String
        if ext.isEmpty == false {
            resolvedExt = ext
        } else if let inferred = UTType(sourceTypeIdentifier)?.preferredFilenameExtension,
                  inferred.isEmpty == false {
            resolvedExt = inferred.lowercased()
        } else {
            resolvedExt = "m4a"
        }

        let baseName = (sourceFilename as NSString).deletingPathExtension
        let sanitized = baseName
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .replacingOccurrences(of: "[^a-zA-Z0-9]+", with: "_", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
            .lowercased()
        let finalStem = sanitized.isEmpty ? "shared_audio" : sanitized
        return "\(finalStem).\(resolvedExt)"
    }

    private struct StagedReceiptPayload: Codable {
        let importID: String
        let sourceFilename: String
        let normalizedFilename: String
        let stagedAudioFilename: String
        let sourceTypeIdentifier: String?
        let byteCount: Int64
        let stagedAtISO8601: String
    }

    private static let iso8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    @MainActor
    private func updateStatus(_ step: String, details: [String: String?] = [:]) {
        resolveSharedPaths()
        attemptSharedLogWrite(step: step, details: details)
    }

    @discardableResult
    private func resolveSharedPaths() -> Bool {
        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default,
            allowFallbackToLocalDocuments: false
        )

        do {
            _ = try store.containerURL().path
            _ = try store.logFileURL().path
            _ = try store.inboxURL().path
            return true
        } catch {
            return false
        }
    }

    private func attemptSharedLogWrite(step: String, details: [String: String?]) {
        let entry = SharedDiagnosticsEntry(
            timestampISO8601: ISO8601DateFormatter().string(from: Date()),
            category: "SHARE_EXT",
            stage: step,
            event: step.hasPrefix("FAIL:") ? "FAIL" : "INFO",
            detail: renderDetails(details)
        )

        do {
            try SharedDiagnosticsLogStore(
                appGroupIdentifier: configuration.appGroupIdentifier,
                fileManager: FileManager.default,
                allowFallbackToLocalDocuments: false
            ).append(entry)
        } catch {
        }

        let detailLine = renderDetails(details)
        let consoleLine = detailLine.isEmpty ? "SHARE_EXT \(step)" : "SHARE_EXT \(step) | \(detailLine)"
        print(consoleLine)
        NSLog("%@", consoleLine)
    }

    private func renderDetails(_ details: [String: String?]) -> String {
        details.keys.sorted().compactMap { key -> String? in
            guard let value = details[key] ?? nil, value.isEmpty == false else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: " | ")
    }

    private func firstAudioCandidate(from providers: [NSItemProvider]) -> ShareAttachmentCandidate? {
        let supportedTypeIdentifiers = [
            UTType.audio.identifier,
            UTType.mpeg4Audio.identifier,
            "com.apple.m4a-audio",
            UTType.mp3.identifier,
            UTType.wav.identifier
        ]

        for provider in providers {
            let registered = provider.registeredTypeIdentifiers
            if let preferred = supportedTypeIdentifiers.first(where: { provider.hasItemConformingToTypeIdentifier($0) }) {
                return ShareAttachmentCandidate(
                    provider: provider,
                    preferredTypeIdentifier: preferred,
                    registeredTypeIdentifiers: registered
                )
            }

            if let registeredAudio = registered.first(where: { identifier in
                UTType(identifier)?.conforms(to: .audio) == true
            }) {
                return ShareAttachmentCandidate(
                    provider: provider,
                    preferredTypeIdentifier: registeredAudio,
                    registeredTypeIdentifiers: registered
                )
            }
        }

        return nil
    }

    private func loadAttachment(_ candidate: ShareAttachmentCandidate) async throws -> LoadedShareAttachment {
        let provider = candidate.provider
        let preferredTypeIdentifier = candidate.preferredTypeIdentifier

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: preferredTypeIdentifier) { sourceURL, error in
                if let error {
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: preferredTypeIdentifier,
                        underlying: error
                    ))
                    return
                }

                guard let sourceURL else {
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: preferredTypeIdentifier,
                        underlying: nil
                    ))
                    return
                }

                guard sourceURL.isFileURL else {
                    continuation.resume(throwing: ShareImportError.loadedItemWasNotFileURL)
                    return
                }

                Task { @MainActor in
                    self.updateStatus("SECURITY SCOPE BEGIN", details: ["path": sourceURL.path])
                }

                let securityScoped = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if securityScoped {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }

                do {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension(sourceURL.pathExtension)
                    if FileManager.default.fileExists(atPath: tempURL.path) {
                        try FileManager.default.removeItem(at: tempURL)
                    }
                    try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                    let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                    let byteCount = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    continuation.resume(returning: LoadedShareAttachment(
                        fileURL: tempURL,
                        sourceFilename: sourceURL.lastPathComponent,
                        sourceTypeIdentifier: preferredTypeIdentifier,
                        byteCount: byteCount
                    ))
                } catch {
                    continuation.resume(throwing: ShareImportError.providerCouldNotLoadItem(
                        typeIdentifier: preferredTypeIdentifier,
                        underlying: error
                    ))
                }
            }
        }
    }

    private func userFacingReason(for error: ShareImportError) -> String {
        switch error {
        case .noAudioAttachmentProviderFound:
            return "Unsupported format"
        case .providerCouldNotLoadItem, .loadedItemWasNotFileURL:
            return "File unreadable"
        case .missingFileExtension:
            return "Unsupported format"
        default:
            return "Please try again"
        }
    }

    private func diagnosticNSError(_ description: String) -> NSError {
        NSError(
            domain: "FamilyRosaryShareExtension.Diagnostics",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
