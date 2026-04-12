import UIKit

final class ShareViewController: UIViewController {
    private let sessionID = UUID().uuidString
    private let configuration = SharedImportConfiguration.fromMainBundle()
    private var didStartStaging = false
    private var statusText = "Preparing share extension…"
    private lazy var bootstrapLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .label
        label.textAlignment = .center
        label.text = "Family Rosary Share Extension Loaded"
        return label
    }()

    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    override func loadView() {
        let rootView = UIView()
        rootView.backgroundColor = .systemBackground
        rootView.addSubview(bootstrapLabel)
        NSLayoutConstraint.activate([
            bootstrapLabel.leadingAnchor.constraint(equalTo: rootView.layoutMarginsGuide.leadingAnchor),
            bootstrapLabel.trailingAnchor.constraint(equalTo: rootView.layoutMarginsGuide.trailingAnchor),
            bootstrapLabel.centerXAnchor.constraint(equalTo: rootView.centerXAnchor),
            bootstrapLabel.centerYAnchor.constraint(equalTo: rootView.centerYAnchor)
        ])
        view = rootView
        bootstrapLabel.text = statusText
        updateStatus("EXTENSION LOADED", details: ["lifecycle": "loadView"])
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startStagingIfNeeded()
    }

    private func startStagingIfNeeded() {
        guard didStartStaging == false else {
            return
        }
        didStartStaging = true

        Task { @MainActor in
            await stageIntoSharedInbox()
        }
    }

    @MainActor
    private func updateStatus(_ text: String, details: [String: String?] = [:]) {
        statusText = text
        bootstrapLabel.text = text
        let logger = makeLogger()
        var merged = details
        merged["controller"] = String(describing: type(of: self))
        logger.log(text, details: merged)
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let renderedDetails = merged.keys.sorted().compactMap { key -> String? in
            guard let value = merged[key] ?? nil, value.isEmpty == false else { return nil }
            return "\(key)=\(value)"
        }.joined(separator: " | ")
        let consoleLine = renderedDetails.isEmpty
            ? "SHARE_EXT \(timestamp) | \(text)"
            : "SHARE_EXT \(timestamp) | \(text) | \(renderedDetails)"
        NSLog("%@", consoleLine)
        print(consoleLine)
    }

    @MainActor
    private func updateFailure(_ text: String, error: Error? = nil, details: [String: String?] = [:]) {
        var merged = details
        if let error {
            merged["error"] = error.localizedDescription
        }
        updateStatus(text, details: merged)
    }

    private func makeLogger() -> ShareImportLogger {
        ShareImportLogger(
            sessionID: sessionID,
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default
        )
    }

    @MainActor
    private func pauseForVisibility() async {
        try? await Task.sleep(nanoseconds: 350_000_000)
    }

    @MainActor
    private func stageIntoSharedInbox() async {
        let logger = makeLogger()

        updateStatus("LOGGING READY", details: [
            "extensionContextPresent": extensionContext == nil ? "NO" : "YES"
        ])
        await pauseForVisibility()

        guard let extensionContext else {
            updateFailure("FAIL: NO INPUT ITEMS", details: ["reason": "extensionContext was nil"])
            didStartStaging = false
            return
        }

        let inputItems = extensionContext.inputItems as? [NSExtensionItem] ?? []
        updateStatus("INPUT ITEMS INSPECTED", details: [
            "inputItemCount": String(inputItems.count)
        ])
        await pauseForVisibility()

        guard inputItems.isEmpty == false else {
            let shareError = ShareImportError.noExtensionInputItems
            updateFailure("FAIL: NO INPUT ITEMS", error: shareError, details: ["reason": "extensionContext.inputItems was empty"])
            logger.fail(shareError.localizedDescription, stage: "INPUT ITEMS INSPECTED", error: shareError)
            extensionContext.cancelRequest(withError: shareError.asNSError)
            didStartStaging = false
            return
        }

        updateStatus("ATTACHMENT SEARCH BEGIN")

        let extractor = ShareAttachmentExtractor(
            logger: logger,
            statusHandler: { [weak self] status, details in
                guard let self else { return }
                Task { @MainActor in
                    self.updateStatus(status, details: details)
                }
            }
        )
        let stagingService = SharedAudioStagingService(
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default,
            logger: ShareImportStagingLogger(
                base: logger,
                statusHandler: { [weak self] status, details in
                    guard let self else { return }
                    Task { @MainActor in
                        self.updateStatus(status, details: details)
                    }
                }
            )
        )

        do {
            let attachment = try await extractor.extractFirstAudioAttachment(from: inputItems)
            let result = try stagingService.stage(
                SharedAudioStagingRequest(
                    sourceFileURL: attachment.fileURL,
                    sourceFilename: attachment.sourceFilename,
                    sourceTypeIdentifier: attachment.sourceTypeIdentifier,
                    byteCount: attachment.byteCount
                )
            )
            updateStatus("COMPLETE REQUEST", details: [
                "importID": result.importID,
                "receiptFilename": result.receiptURL.lastPathComponent
            ])
            extensionContext.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            let shareError = mapToShareImportError(error)
            logger.fail(shareError.localizedDescription, stage: "SESSION", error: shareError)
            updateFailure("FAIL: \(failureText(for: shareError))", error: shareError)
            extensionContext.cancelRequest(withError: shareError.asNSError)
            didStartStaging = false
        }
    }

    private func failureText(for error: ShareImportError) -> String {
        switch error {
        case .noExtensionInputItems:
            return "NO INPUT ITEMS"
        case .noAttachmentsOnExtensionItem, .noAudioAttachmentProviderFound:
            return "NO AUDIO ATTACHMENT"
        case .providerCouldNotLoadItem:
            return "LOAD ITEM ERROR"
        case .loadedItemWasNotFileURL:
            return "ITEM NOT URL"
        case .appGroupContainerUnavailable:
            return "APP GROUP UNAVAILABLE"
        case .failedToCreateInboxDirectory:
            return "COPY SETUP FAILED"
        case .failedToCopySharedAudioIntoAppGroup:
            return "COPY FAILED"
        case .destinationFileAlreadyExists:
            return "DESTINATION EXISTS"
        case .copiedFileIsEmpty:
            return "COPIED FILE EMPTY"
        case .failedToPersistSharedAudioManifest:
            return "MANIFEST WRITE FAILED"
        case .missingFileExtension:
            return "MISSING FILE EXTENSION"
        }
    }

    private func mapToShareImportError(_ error: Error) -> ShareImportError {
        if let shareImportError = error as? ShareImportError {
            return shareImportError
        }
        if let stagingError = error as? SharedAudioStagingError {
            switch stagingError {
            case .appGroupIdentifierMissing, .appGroupContainerUnavailable:
                return .appGroupContainerUnavailable(appGroupIdentifier: configuration.appGroupIdentifier)
            case .failedToCreateInboxDirectory:
                return .failedToCreateInboxDirectory(underlying: stagingError as NSError)
            case .destinationFileAlreadyExists(let path):
                return .destinationFileAlreadyExists(path: path)
            case .failedToCopySharedAudioIntoAppGroup:
                return .failedToCopySharedAudioIntoAppGroup(underlying: stagingError as NSError)
            case .copiedFileIsEmpty:
                return .copiedFileIsEmpty
            case .failedToPersistSharedAudioManifest:
                return .failedToPersistSharedAudioManifest(underlying: stagingError as NSError)
            case .missingFileExtension:
                return .missingFileExtension
            }
        }
        return .providerCouldNotLoadItem(typeIdentifier: "public.audio", underlying: error)
    }
}
