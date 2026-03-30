import UIKit
import Social

final class ShareViewController: SLComposeServiceViewController {
    private var didStartStaging = false
    private var statusText = "Preparing recording…"

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

        statusText = "Preparing recording…"
        placeholder = statusText

        Task { @MainActor in
            await stageAndOpenApp()
        }
    }

    @MainActor
    private func stageAndOpenApp() async {
        let configuration = SharedImportConfiguration.fromMainBundle()
        let stager = SharedRecordingStager(configuration: configuration)
        NSLog("SHARE_IMPORT_EXT controller started")

        do {
            let staged = try await stager.stageFirstAudio(from: extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            NSLog("SHARE_IMPORT_EXT staged import=%@", staged.importID)
            if let url = configuration.makeShareImportURL(importID: staged.importID) {
                NSLog("SHARE_IMPORT_EXT opening app via URL=%@", url.absoluteString)
                extensionContext?.open(url) { [weak self] _ in
                    self?.extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
                }
            } else {
                NSLog("SHARE_IMPORT_EXT could not build deep link URL")
                extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
            }
        } catch {
            NSLog("SHARE_IMPORT_EXT failed with error=%@", error.localizedDescription)
            let message = error.localizedDescription
            statusText = message
            placeholder = message
            presentErrorAlert(message: message)
            didStartStaging = false
        }
    }

    private func presentErrorAlert(message: String) {
        let alert = UIAlertController(title: "Share Failed", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Close", style: .cancel))
        present(alert, animated: true)
    }
}
