import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class ShareImportPreviewViewModelTests: XCTestCase {
    func testSingleItemPreviewState() {
        let discovery = FakeDiscoveryService(items: [
            makeReadyItem(importID: "a")
        ])
        let viewModel = makeViewModel(discovery: discovery)

        viewModel.scanInboxAndPresent()

        XCTAssertTrue(viewModel.isPresented)
        XCTAssertEqual(viewModel.items.count, 1)
        XCTAssertEqual(viewModel.headline, "Review Shared Recording")
        XCTAssertTrue(viewModel.items[0].isActionable)
    }

    func testMultiplePendingItemsState() {
        let discovery = FakeDiscoveryService(items: [
            makeReadyItem(importID: "a"),
            makeMalformedItem(importID: "b", reason: "Missing receipt")
        ])
        let viewModel = makeViewModel(discovery: discovery)

        viewModel.scanInboxAndPresent()

        XCTAssertTrue(viewModel.isPresented)
        XCTAssertEqual(viewModel.items.count, 2)
        XCTAssertEqual(viewModel.headline, "Shared Recordings")
        XCTAssertEqual(viewModel.items[1].statusMessage, "Missing receipt")
    }

    func testMalformedDeepLinkDoesNotCrash() {
        let viewModel = makeViewModel(discovery: FakeDiscoveryService(items: []))
        viewModel.handleIncomingURL(URL(string: "https://example.com")!)
        XCTAssertFalse(viewModel.isPresented)
    }

    func testRecognizedDeepLinkTriggersScan() {
        let viewModel = makeViewModel(discovery: FakeDiscoveryService(items: [makeReadyItem(importID: "a")]))
        viewModel.handleIncomingURL(URL(string: "familyrosary://share-import")!)
        XCTAssertTrue(viewModel.isPresented)
    }

    private func makeViewModel(discovery: SharedRecordingDiscovering) -> ShareImportPreviewViewModel {
        ShareImportPreviewViewModel(
            discoveryService: discovery,
            audioInspector: PassingAudioInspector(),
            pipeline: FakePipeline(),
            deepLinkHandler: ShareImportDeepLinkHandler(expectedScheme: "familyrosary"),
            previewPlayer: FakePreviewPlayer()
        )
    }

    private func makeReadyItem(importID: String) -> SharedRecordingDiscoveredItem {
        let receipt = SharedRecordingReceipt(
            importID: importID,
            sourceFilename: "Memo.m4a",
            normalizedFilename: "memo.m4a",
            stagedAudioFilename: "memo.m4a",
            sourceTypeIdentifier: "public.mpeg-4-audio",
            byteCount: 12,
            stagedAtISO8601: "2026-03-30T00:00:00.000Z"
        )
        let folderURL = URL(fileURLWithPath: "/tmp/\(importID)", isDirectory: true)
        return SharedRecordingDiscoveredItem(
            id: importID,
            importID: importID,
            folderURL: folderURL,
            receiptURL: folderURL.appendingPathComponent("receipt.json"),
            receipt: receipt,
            audioFileURL: folderURL.appendingPathComponent(receipt.stagedAudioFilename),
            status: .ready
        )
    }

    private func makeMalformedItem(importID: String, reason: String) -> SharedRecordingDiscoveredItem {
        let folderURL = URL(fileURLWithPath: "/tmp/\(importID)", isDirectory: true)
        return SharedRecordingDiscoveredItem(
            id: importID,
            importID: importID,
            folderURL: folderURL,
            receiptURL: folderURL.appendingPathComponent("receipt.json"),
            receipt: nil,
            audioFileURL: nil,
            status: .malformed(reason: reason)
        )
    }
}

private struct FakeDiscoveryService: SharedRecordingDiscovering {
    let items: [SharedRecordingDiscoveredItem]
    func discover() -> [SharedRecordingDiscoveredItem] { items }
}

private struct FakePipeline: SharedRecordingImportRunning {
    func processAllPending() async -> [SharedRecordingImportResult] { [] }
    func process(importID: String) async -> SharedRecordingImportResult {
        SharedRecordingImportResult(
            importID: importID,
            status: .failed(message: "not implemented in fake")
        )
    }
}

private struct FakePreviewPlayer: SharedImportPreviewPlaying {
    func play(url: URL) throws { _ = url }
    func stop() {}
}

private struct PassingAudioInspector: SharedAudioInspecting {
    func inspect(url: URL) throws -> SharedAudioInspection {
        _ = url
        return SharedAudioInspection(durationSeconds: 5.0)
    }
}
