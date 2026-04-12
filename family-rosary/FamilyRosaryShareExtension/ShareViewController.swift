import UIKit

final class ShareViewController: UIViewController {
    private let sessionID = UUID().uuidString
    private let configuration = SharedImportConfiguration.fromMainBundle()
    private var didStartStaging = false
    private var didLogBootstrap = false
    private var statusText = "Importing recording…"
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
        logBootstrapIfNeeded(lifecycle: "init(nibName:bundle:)")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        logBootstrapIfNeeded(lifecycle: "init(coder:)")
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
        updateStatus("Family Rosary Share Extension Loaded")
        logBootstrapIfNeeded(lifecycle: "loadView")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateStatus("Family Rosary Share Extension Loaded")
        logBootstrapIfNeeded(lifecycle: "viewDidLoad")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logLifecycleEvent("VIEW_WILL_APPEAR")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logLifecycleEvent("VIEW_DID_APPEAR")
        startStagingIfNeeded()
    }

    private func startStagingIfNeeded() {
        guard didStartStaging == false else {
            return
        }
        didStartStaging = true

        updateStatus("Importing recording…")

        Task { @MainActor in
            await stageIntoSharedInbox()
        }
    }

    private func updateStatus(_ text: String) {
        statusText = text
        bootstrapLabel.text = text
    }

    private func logBootstrapIfNeeded(lifecycle: String) {
        guard didLogBootstrap == false else { return }
        didLogBootstrap = true

        let logger = ShareImportLogger(
            sessionID: sessionID,
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default
        )

        let containerPath = (try? SharedDiagnosticsLogStore(
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default
        ).containerURL().path) ?? "nil"

        let details: [String: String?] = [
            "controller": String(describing: type(of: self)),
            "lifecycle": lifecycle,
            "appGroupIdentifier": configuration.appGroupIdentifier,
            "containerPath": containerPath,
            "extensionContextPresent": extensionContext == nil ? "NO" : "YES"
        ]

        logger.log("SESSION_BEGIN", details: details)
        if configuration.appGroupIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logger.fail("Missing app group identifier.", stage: "SESSION_BEGIN")
        }
        logger.logSharedContainerDetails()
        let consoleLine = "SHARE_EXT SESSION_BEGIN | session=\(sessionID) | controller=\(String(describing: type(of: self))) | lifecycle=\(lifecycle) | appGroupIdentifier=\(configuration.appGroupIdentifier) | containerPath=\(containerPath) | extensionContextPresent=\(extensionContext == nil ? "NO" : "YES")"
        NSLog("%@", consoleLine)
        print(consoleLine)
    }

    private func logLifecycleEvent(_ stage: String) {
        let configuration = SharedImportConfiguration.fromMainBundle()
        let logger = ShareImportLogger(
            sessionID: sessionID,
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default
        )
        logger.log(stage, details: [
            "controller": String(describing: type(of: self)),
            "extensionContextPresent": extensionContext == nil ? "NO" : "YES",
            "inputItemCount": String((extensionContext?.inputItems.count) ?? 0)
        ])
        NSLog("SHARE_EXT | session=%@ | stage=%@ | controller=%@ | extensionContextPresent=%@ | inputItemCount=%@",
              sessionID,
              stage,
              String(describing: type(of: self)),
              extensionContext == nil ? "NO" : "YES",
              String((extensionContext?.inputItems.count) ?? 0))
    }

    @MainActor
    private func stageIntoSharedInbox() async {
        // The previous flow treated "cannot open the main app right now" as a hard share failure.
        // This extension now succeeds once the audio file is durably staged into the shared inbox.
        let logger = ShareImportLogger(
            sessionID: sessionID,
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default
        )
        logger.log("STAGING_BEGIN", details: ["controller": "ShareViewController"])
        logger.logSharedContainerDetails()
        do {
            try logger.validateSharedContainerAvailability()
        } catch {
            let shareError = (error as? ShareImportError) ?? .appGroupContainerUnavailable(appGroupIdentifier: configuration.appGroupIdentifier)
            logger.fail(shareError.localizedDescription, stage: "SESSION_BEGIN", error: shareError)
            let message = shareError.localizedDescription
            updateStatus(message)
            extensionContext?.cancelRequest(withError: shareError.asNSError)
            didStartStaging = false
            return
        }
        logger.writeExtensionCanary()
        let extractor = ShareAttachmentExtractor(logger: logger)
        let stagingService = SharedAudioStagingService(
            appGroupIdentifier: configuration.appGroupIdentifier,
            fileManager: FileManager.default,
            logger: ShareImportStagingLogger(base: logger)
        )

        do {
            let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
            let attachment = try await extractor.extractFirstAudioAttachment(from: inputItems)
            let result = try stagingService.stage(
                SharedAudioStagingRequest(
                    sourceFileURL: attachment.fileURL,
                    sourceFilename: attachment.sourceFilename,
                    sourceTypeIdentifier: attachment.sourceTypeIdentifier,
                    byteCount: attachment.byteCount
                )
            )
            logger.log("COMPLETE_REQUEST", details: [
                "importID": result.importID,
                "receiptFilename": result.receiptURL.lastPathComponent
            ])
            updateStatus("Saved to Family Rosary inbox.")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            let shareError = mapToShareImportError(error)
            logger.fail(shareError.localizedDescription, stage: "SESSION", error: shareError)
            let message = shareError.localizedDescription
            updateStatus(message)
            extensionContext?.cancelRequest(withError: shareError.asNSError)
            didStartStaging = false
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
