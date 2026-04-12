import Foundation

struct SharedInboxSimulatedShareRunResult: Equatable {
    let importID: String
    let stagedAudioPath: String
    let receiptPath: String
    let discoveredItemCount: Int
    let pipelineResult: SharedRecordingImportResult
}

struct SharedInboxSimulatedShareRunner {
    let injector: SharedInboxDebugInjector
    let discoveryService: SharedRecordingDiscovering
    let pipeline: SharedRecordingImportRunning
    let simLogger: SharedDiagnosticsLogger
    let importLogger: SharedDiagnosticsLogger

    func run() async throws -> SharedInboxSimulatedShareRunResult {
        simLogger.log(stage: "TEST_BEGIN", event: "INFO")

        do {
            let injection = try injector.injectBundledTestAudio()
            let discovered = discoveryService.discover()
            importLogger.log(stage: "SCAN_BEGIN", event: "INFO", detail: "count=\(discovered.count)")

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

            importLogger.log(stage: "ITEM_FOUND", event: "INFO", detail: "importID=\(injection.importID)")
            let result = await pipeline.process(importID: injection.importID)

            switch result.status {
            case .imported(let imported):
                importLogger.log(
                    stage: "SCAN_COMPLETE",
                    event: "SUCCESS",
                    detail: "importID=\(result.importID) file=\(imported.filename)"
                )
                simLogger.log(
                    stage: "TEST_SUCCESS",
                    event: "SUCCESS",
                    detail: "importID=\(injection.importID) staged=\(injection.stagedAudioURL.path)"
                )
            case .failed(let message):
                importLogger.log(
                    stage: "SCAN_COMPLETE",
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
