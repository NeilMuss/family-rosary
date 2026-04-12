import Foundation

protocol SharedInboxSimulatedShareRunning {
    func run() async throws -> SharedInboxSimulatedShareRunResult
}

struct SharedInboxSimulatedShareRunResult: Equatable {
    let importID: String
    let stagedAudioPath: String
    let receiptPath: String
    let discoveredItemCount: Int
    let pipelineResult: SharedRecordingImportResult
}

struct SharedInboxSimulatedShareRunner: SharedInboxSimulatedShareRunning {
    let injector: SharedInboxDebugInjector
    let discoveryService: SharedRecordingDiscovering
    let pipeline: SharedRecordingImportRunning
    let simLogger: SharedDiagnosticsLogger
    let importLogger: SharedDiagnosticsLogger
    let partnerName: String

    init(
        injector: SharedInboxDebugInjector,
        discoveryService: SharedRecordingDiscovering,
        pipeline: SharedRecordingImportRunning,
        simLogger: SharedDiagnosticsLogger,
        importLogger: SharedDiagnosticsLogger,
        partnerName: String = "TEST"
    ) {
        self.injector = injector
        self.discoveryService = discoveryService
        self.pipeline = pipeline
        self.simLogger = simLogger
        self.importLogger = importLogger
        self.partnerName = partnerName
    }

    func run() async throws -> SharedInboxSimulatedShareRunResult {
        // Simulator coverage begins after file acquisition.
        // This path exercises the same shared staging service as the extension,
        // but it does not cover the literal iOS share event or NSItemProvider quirks.
        simLogger.log(stage: "Startup simulated share test beginning.", event: "INFO")
        do {
            simLogger.log(stage: "Temporary import file copy beginning.", event: "INFO")
            simLogger.log(stage: "Shared staging service write beginning.", event: "INFO")
            let injection = try injector.injectBundledTestAudio()
            simLogger.log(
                stage: "Bundled source file located: \(SharedInboxDebugInjector.bundledAssetName).\(SharedInboxDebugInjector.bundledAssetExtension)",
                event: "INFO"
            )
            simLogger.log(
                stage: "Temporary import file copy succeeded: \(injection.stagedAudioURL.path)",
                event: "INFO"
            )
            simLogger.log(
                stage: "Shared staging service write succeeded.",
                event: "INFO",
                detail: injection.receiptURL.path
            )
            let discovered = discoveryService.discover()
            importLogger.log(
                stage: "Import process beginning for partner \(partnerName).",
                event: "INFO",
                detail: "count=\(discovered.count)"
            )

            guard discovered.contains(where: { $0.importID == injection.importID }) else {
                importLogger.log(stage: "SCAN_COMPLETE", event: "FAIL", detail: "missingImportID=\(injection.importID)")
                let error = NSError(
                    domain: "SharedInboxSimulatedShareRunner",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Simulated share failed: the staged item was not discovered by the app import scan."]
                )
                simLogger.log(stage: "FAIL", event: "FAIL", detail: error.localizedDescription)
                throw error
            }

            importLogger.log(
                stage: "Import file confirmed at path: \(injection.stagedAudioURL.path)",
                event: "INFO",
                detail: "partner=\(partnerName)"
            )
            let result = await pipeline.process(importID: injection.importID)

            switch result.status {
            case .imported(let imported):
                importLogger.log(
                    stage: "Import process succeeded for partner \(partnerName).",
                    event: "SUCCESS",
                    detail: "importID=\(result.importID) file=\(imported.filename)"
                )
                simLogger.log(
                    stage: "Startup simulated share test succeeded.",
                    event: "SUCCESS",
                    detail: "importID=\(injection.importID) staged=\(injection.stagedAudioURL.path)"
                )
            case .failed(let message):
                importLogger.log(
                    stage: "Import process failed for partner \(partnerName).",
                    event: "FAIL",
                    detail: "importID=\(result.importID) reason=\(message)"
                )
                simLogger.log(stage: "FAIL", event: "FAIL", detail: message)
            }

            return SharedInboxSimulatedShareRunResult(
                importID: injection.importID,
                stagedAudioPath: injection.stagedAudioURL.path,
                receiptPath: injection.receiptURL.path,
                discoveredItemCount: discovered.count,
                pipelineResult: result
            )
        } catch {
            simLogger.log(stage: "FAIL", event: "FAIL", detail: error.localizedDescription)
            throw error
        }
    }
}
