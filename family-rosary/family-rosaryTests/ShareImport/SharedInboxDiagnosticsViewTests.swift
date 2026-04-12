import Foundation
import XCTest
@testable import family_rosary

final class SharedInboxDiagnosticsViewTests: XCTestCase {
    func testCopyActionUsesExactVisibleLogText() {
        let entries = [
            SharedDiagnosticsEntry(
                timestampISO8601: "2026-04-12T12:00:00.000Z",
                category: "APP",
                stage: "App initialized.",
                event: "INFO",
                detail: nil
            ),
            SharedDiagnosticsEntry(
                timestampISO8601: "2026-04-12T12:00:01.000Z",
                category: "SIM_SHARE",
                stage: "Startup simulated share test beginning.",
                event: "INFO",
                detail: nil
            )
        ]

        let copiedText = Box<String?>(nil)
        let action = SharedInboxDiagnosticsCopyAction(
            clipboardWriter: TestClipboardWriter { copiedText.value = $0 }
        )
        let visibleLogText = entries.map(\.formattedLine).joined(separator: "\n")

        let confirmation = action.copy(logText: visibleLogText)

        XCTAssertEqual(
            copiedText.value,
            """
            2026-04-12T12:00:00.000Z | APP | App initialized. | INFO
            2026-04-12T12:00:01.000Z | SIM_SHARE | Startup simulated share test beginning. | INFO
            """
        )
        XCTAssertEqual(confirmation, "Logs copied.")
    }

    func testCopyActionUsesDeterministicEmptyLogText() {
        let copiedText = Box<String?>(nil)
        let action = SharedInboxDiagnosticsCopyAction(
            clipboardWriter: TestClipboardWriter { copiedText.value = $0 }
        )

        let confirmation = action.copy(logText: "No logs yet.")

        XCTAssertEqual(copiedText.value, "No logs yet.")
        XCTAssertEqual(confirmation, "No logs yet.")
    }
}

private final class Box<T> {
    var value: T

    init(_ value: T) {
        self.value = value
    }
}

private struct TestClipboardWriter: ClipboardWriting {
    let onWrite: (String) -> Void

    func write(_ text: String) {
        onWrite(text)
    }
}
