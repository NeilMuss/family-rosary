import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let sessionID = UUID().uuidString
    private let configuration = SharedImportConfiguration.fromMainBundle()
    private var didStartDiagnostics = false
    private var currentStep = "Preparing diagnostic screen…"
    private var lastLifecycleEvent = "init"
    private var sharedLogWriteStatus = "NOT ATTEMPTED"
    private var appGroupContainerPath = "nil"
    private var logFilePath = "nil"
    private var inboxPath = "nil"
    private var extraDetail = ""

    private lazy var debugLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 16, weight: .regular)
        label.textColor = .label
        label.textAlignment = .left
        label.text = ""
        return label
    }()

    override func loadView() {
        lastLifecycleEvent = "loadView"

        let rootView = UIView()
        rootView.backgroundColor = .systemBackground
        rootView.addSubview(debugLabel)
        NSLayoutConstraint.activate([
            debugLabel.leadingAnchor.constraint(equalTo: rootView.layoutMarginsGuide.leadingAnchor),
            debugLabel.trailingAnchor.constraint(equalTo: rootView.layoutMarginsGuide.trailingAnchor),
            debugLabel.topAnchor.constraint(equalTo: rootView.safeAreaLayoutGuide.topAnchor, constant: 20),
            debugLabel.bottomAnchor.constraint(lessThanOrEqualTo: rootView.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
        view = rootView

        updateStatus("EXTENSION LOADED", details: ["lifecycle": lastLifecycleEvent])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        lastLifecycleEvent = "viewDidLoad"
        refreshDebugView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        lastLifecycleEvent = "viewWillAppear"
        refreshDebugView()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        lastLifecycleEvent = "viewDidAppear"
        refreshDebugView()
        startDiagnosticsIfNeeded()
    }

    private func startDiagnosticsIfNeeded() {
        guard didStartDiagnostics == false else { return }
        didStartDiagnostics = true

        Task { @MainActor in
            await runDiagnostics()
        }
    }

    @MainActor
    private func runDiagnostics() async {
        updateStatus("LOGGING READY", details: [
            "extensionContextPresent": extensionContext == nil ? "NO" : "YES"
        ])
        await delayForReadability()

        guard resolveSharedPaths() else {
            if appGroupContainerPath == "nil" {
                await failAndHold("FAIL: APP GROUP CONTAINER NIL", details: [
                    "reason": "containerURL() returned nil"
                ])
            } else {
                await failAndHold("FAIL: LOG FILE URL NIL", details: [
                    "reason": "logFileURL() could not be resolved"
                ])
            }
            return
        }

        guard let extensionContext else {
            await failAndHold("FAIL: NO EXTENSIONCONTEXT", details: [
                "reason": "extensionContext was nil"
            ])
            return
        }

        let inputItems = extensionContext.inputItems as? [NSExtensionItem] ?? []
        updateStatus("INPUT ITEMS INSPECTED", details: [
            "inputItemCount": String(inputItems.count)
        ])
        await delayForReadability()

        guard inputItems.isEmpty == false else {
            await failAndHold("FAIL: NO INPUT ITEMS", details: [
                "reason": "extensionContext.inputItems was empty"
            ])
            return
        }

        updateStatus("ATTACHMENT SEARCH BEGIN")
        await delayForReadability()

        let providers = inputItems.flatMap { $0.attachments ?? [] }
        guard providers.isEmpty == false else {
            await failAndHold("FAIL: NO ATTACHMENTS", details: [
                "reason": "No attachments found on extension items"
            ])
            return
        }

        guard let candidate = firstAudioCandidate(from: providers) else {
            let seenTypes = providers.flatMap(\.registeredTypeIdentifiers).joined(separator: ",")
            await failAndHold("FAIL: NO AUDIO PROVIDER", details: [
                "registeredTypeIdentifiers": seenTypes
            ])
            return
        }

        updateStatus("ATTACHMENT FOUND", details: [
            "typeIdentifier": candidate.preferredTypeIdentifier,
            "registeredTypeIdentifiers": candidate.registeredTypeIdentifiers.joined(separator: ",")
        ])
        await delayForReadability()

        updateStatus("LOAD ITEM BEGIN", details: [
            "typeIdentifier": candidate.preferredTypeIdentifier
        ])

        do {
            let loaded = try await loadAttachment(candidate)
            updateStatus("LOAD ITEM SUCCESS", details: [
                "sourceFilename": loaded.sourceFilename,
                "byteCount": String(loaded.byteCount)
            ])
            await holdForInspection()
            extensionContext.cancelRequest(withError: diagnosticNSError("Diagnostic hold completed after LOAD ITEM SUCCESS."))
        } catch let error as ShareImportError {
            switch error {
            case .loadedItemWasNotFileURL:
                await failAndHold("FAIL: ITEM NOT URL", details: [
                    "reason": error.localizedDescription
                ])
            case .providerCouldNotLoadItem:
                await failAndHold("FAIL: LOAD ITEM ERROR", details: [
                    "reason": error.localizedDescription
                ])
            default:
                await failAndHold("FAIL: LOAD ITEM ERROR", details: [
                    "reason": error.localizedDescription
                ])
            }
        } catch {
            await failAndHold("FAIL: LOAD ITEM ERROR", details: [
                "reason": error.localizedDescription
            ])
        }
    }

    @MainActor
    private func updateStatus(_ step: String, details: [String: String?] = [:]) {
        currentStep = step
        extraDetail = renderDetails(details)
        resolveSharedPaths()
        attemptSharedLogWrite(step: step, details: details)
        refreshDebugView()
    }

    @MainActor
    private func failAndHold(_ step: String, details: [String: String?] = [:]) async {
        updateStatus(step, details: details)
        await holdForInspection()
        extensionContext?.cancelRequest(withError: diagnosticNSError(step))
    }

    @discardableResult
    private func resolveSharedPaths() -> Bool {
        let store = SharedDiagnosticsLogStore(
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default,
            allowFallbackToLocalDocuments: false
        )

                print("SHARE EXTENSION containerURL =", try? store.containerURL())
        print("SHARE EXTENSION logFileURL =", try? store.logFileURL())
        print("SHARE EXTENSION inboxURL =", try? store.inboxURL())

        do {
            appGroupContainerPath = try store.containerURL().path
        } catch {
            appGroupContainerPath = "nil"
            logFilePath = "nil"
            inboxPath = "nil"
            return false
        }

        do {
            logFilePath = try store.logFileURL().path
        } catch {
            logFilePath = "nil"
            return false
        }

        do {
            inboxPath = try store.inboxURL().path
        } catch {
            inboxPath = "nil"
        }

        return true
    }

    private func attemptSharedLogWrite(step: String, details: [String: String?]) {
        sharedLogWriteStatus = "ATTEMPTED"
        refreshDebugView()

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
            sharedLogWriteStatus = "SUCCEEDED"
        } catch {
            if let shareError = error as? ShareImportError,
               case .appGroupContainerUnavailable = shareError {
                sharedLogWriteStatus = "FAILED app group unavailable"
            } else {
                sharedLogWriteStatus = "FAILED \(error.localizedDescription)"
            }
        }

        let detailLine = renderDetails(details)
        let consoleLine = detailLine.isEmpty ? "SHARE_EXT \(step)" : "SHARE_EXT \(step) | \(detailLine)"
        print(consoleLine)
        NSLog("%@", consoleLine)
    }

    private func refreshDebugView() {
        debugLabel.text = [
            "ENTRY CLASS: \(String(describing: type(of: self)))",
            "STEP: \(currentStep)",
            "LIFECYCLE: \(lastLifecycleEvent)",
            "APP GROUP ID: \(configuration.appGroupIdentifier.isEmpty ? "nil" : configuration.appGroupIdentifier)",
            "APP GROUP CONTAINER URL: \(appGroupContainerPath)",
            "LOG FILE URL: \(logFilePath)",
            "INBOX URL: \(inboxPath)",
            "SHARED LOG WRITE: \(sharedLogWriteStatus)",
            extraDetail.isEmpty ? nil : "DETAIL: \(extraDetail)"
        ]
        .compactMap { $0 }
        .joined(separator: "\n")
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

    @MainActor
    private func delayForReadability() async {
        try? await Task.sleep(nanoseconds: 1_000_000_000)
    }

    @MainActor
    private func holdForInspection() async {
        try? await Task.sleep(nanoseconds: 5_000_000_000)
    }

    private func diagnosticNSError(_ description: String) -> NSError {
        NSError(
            domain: "FamilyRosaryShareExtension.Diagnostics",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: description]
        )
    }
}
