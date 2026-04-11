import UIKit
import Social

final class ShareViewController: SLComposeServiceViewController {
    private var didStartStaging = false
    private var statusText = "Importing recording…"

    override func isContentValid() -> Bool {
        true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        placeholder = statusText
        startStagingIfNeeded()
    }

    override func didSelectPost() {
        startStagingIfNeeded()
    }

    override func configurationItems() -> [Any]! {
        []
    }

    private func startStagingIfNeeded() {
        guard didStartStaging == false else {
            return
        }
        didStartStaging = true

        statusText = "Importing recording…"
        placeholder = statusText

        Task { @MainActor in
            await stageIntoSharedInbox()
        }
    }

    @MainActor
    private func stageIntoSharedInbox() async {
        // The previous flow treated "cannot open the main app right now" as a hard share failure.
        // This extension now succeeds once the audio file is durably staged into the shared inbox.
        let configuration = SharedImportConfiguration.fromMainBundle()
        let logger = ShareImportLogger(sessionID: UUID().uuidString)
        let extractor = ShareAttachmentExtractor(logger: logger)
        let writer = SharedAudioInboxWriter(configuration: configuration, logger: logger)
        logger.log("SESSION_BEGIN", details: ["controller": "ShareViewController"])

        do {
            let inputItems = extensionContext?.inputItems as? [NSExtensionItem] ?? []
            let attachment = try await extractor.extractFirstAudioAttachment(from: inputItems)
            let result = try writer.write(attachment: attachment)
            logger.log("COMPLETE_REQUEST", details: [
                "importID": result.importID,
                "receiptFilename": result.receiptURL.lastPathComponent
            ])
            statusText = "Saved to Family Rosary inbox."
            placeholder = statusText
            extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
        } catch {
            let shareError = (error as? ShareImportError) ?? .providerCouldNotLoadItem(typeIdentifier: "public.audio", underlying: error)
            logger.fail(shareError.localizedDescription, stage: "SESSION", error: shareError)
            let message = shareError.localizedDescription
            statusText = message
            placeholder = message
            extensionContext?.cancelRequest(withError: shareError.asNSError)
            didStartStaging = false
        }
    }
}
