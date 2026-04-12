import UIKit

final class ShareViewController: UIViewController {
    private let sessionID = UUID().uuidString
    private var didStartStaging = false
    private var didLogBootstrap = false
    private var statusText = "Importing recording…"
    private lazy var bootstrapLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 13, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.text = "Family Rosary Share Extension Loaded"
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        installBootstrapLabelIfNeeded()
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

    private func installBootstrapLabelIfNeeded() {
        guard bootstrapLabel.superview == nil else { return }
        view.addSubview(bootstrapLabel)
        NSLayoutConstraint.activate([
            bootstrapLabel.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            bootstrapLabel.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
            bootstrapLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            bootstrapLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    private func updateStatus(_ text: String) {
        statusText = text
        bootstrapLabel.text = text
    }

    private func logBootstrapIfNeeded(lifecycle: String) {
        guard didLogBootstrap == false else { return }
        didLogBootstrap = true

        let configuration = SharedImportConfiguration.fromMainBundle()
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
        NSLog("SHARE_EXT | session=%@ | stage=SESSION_BEGIN | controller=%@ | lifecycle=%@ | appGroupIdentifier=%@ | containerPath=%@ | extensionContextPresent=%@",
              sessionID,
              String(describing: type(of: self)),
              lifecycle,
              configuration.appGroupIdentifier,
              containerPath,
              extensionContext == nil ? "NO" : "YES")
        print("SHARE_EXT | session=\(sessionID) | stage=SESSION_BEGIN | controller=\(String(describing: type(of: self))) | lifecycle=\(lifecycle) | appGroupIdentifier=\(configuration.appGroupIdentifier) | containerPath=\(containerPath) | extensionContextPresent=\(extensionContext == nil ? "NO" : "YES")")
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
        let configuration = SharedImportConfiguration.fromMainBundle()
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
        let writer = SharedAudioInboxWriter(configuration: configuration, logger: logger)

        do {
            let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
            let attachment = try await extractor.extractFirstAudioAttachment(from: inputItems)
            let result = try writer.write(attachment: attachment)
            logger.log("COMPLETE_REQUEST", details: [
                "importID": result.importID,
                "receiptFilename": result.receiptURL.lastPathComponent
            ])
            updateStatus("Saved to Family Rosary inbox.")
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            let shareError = (error as? ShareImportError) ?? .providerCouldNotLoadItem(typeIdentifier: "public.audio", underlying: error)
            logger.fail(shareError.localizedDescription, stage: "SESSION", error: shareError)
            let message = shareError.localizedDescription
            updateStatus(message)
            extensionContext?.cancelRequest(withError: shareError.asNSError)
            didStartStaging = false
        }
    }
}
