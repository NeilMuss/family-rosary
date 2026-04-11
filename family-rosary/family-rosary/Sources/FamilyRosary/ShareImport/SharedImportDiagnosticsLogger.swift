import Foundation

struct SharedImportDiagnosticsLogger {
    enum Event: String {
        case pass = "PASS"
        case fail = "FAIL"
        case info = "INFO"
    }

    private let sharedLogger: SharedDiagnosticsLogger?

    init(sharedLogger: SharedDiagnosticsLogger? = nil) {
        self.sharedLogger = sharedLogger
    }

    func log(
        sessionID: String,
        importID: String?,
        stage: String,
        event: Event,
        path: String? = nil,
        reason: String? = nil
    ) {
        var components: [String] = [
            "SHARE_IMPORT",
            "session=\(sessionID)",
            "stage=\(stage)",
            "event=\(event.rawValue)"
        ]

        if let importID, importID.isEmpty == false {
            components.append("import=\(importID)")
        }
        if let path, path.isEmpty == false {
            components.append("path=\(path)")
        }
        if let reason, reason.isEmpty == false {
            components.append("reason=\(reason)")
        }

        let line = components.joined(separator: " | ")
        DebugLog.shared.log(line)
        sharedLogger?.log(stage: stage, event: event.rawValue, detail: line)
    }
}
