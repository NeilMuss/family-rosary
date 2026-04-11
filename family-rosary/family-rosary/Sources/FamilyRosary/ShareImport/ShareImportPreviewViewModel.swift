import Foundation
import AVFoundation
import Combine

protocol SharedImportPreviewPlaying {
    func play(url: URL) throws
    func stop()
}

final class AVSharedImportPreviewPlayer: NSObject, SharedImportPreviewPlaying {
    private var player: AVAudioPlayer?

    func play(url: URL) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        self.player = player
        player.play()
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

struct ShareImportPreviewItem: Identifiable, Equatable {
    let id: String
    let importID: String
    let filename: String
    let durationText: String?
    let statusMessage: String
    let isActionable: Bool
    let audioURL: URL?
}

@MainActor
final class ShareImportPreviewViewModel: ObservableObject {
    @Published var isPresented = false
    @Published private(set) var items: [ShareImportPreviewItem] = []
    @Published private(set) var headline: String = ""
    @Published var errorMessage: String?

    private let discoveryService: SharedRecordingDiscovering
    private let audioInspector: SharedAudioInspecting
    private let pipeline: SharedRecordingImportRunning
    private let deepLinkHandler: ShareImportDeepLinkHandler
    private let previewPlayer: SharedImportPreviewPlaying

    init(
        discoveryService: SharedRecordingDiscovering,
        audioInspector: SharedAudioInspecting,
        pipeline: SharedRecordingImportRunning,
        deepLinkHandler: ShareImportDeepLinkHandler,
        previewPlayer: SharedImportPreviewPlaying
    ) {
        self.discoveryService = discoveryService
        self.audioInspector = audioInspector
        self.pipeline = pipeline
        self.deepLinkHandler = deepLinkHandler
        self.previewPlayer = previewPlayer
    }

    func handleIncomingURL(_ url: URL) {
        guard deepLinkHandler.recognizes(url) else {
            return
        }
        scanInboxAndPresent()
    }

    func scanInboxAndPresent() {
        let discovered = discoveryService.discover()
        let mapped = discovered.map { item in
            switch item.status {
            case .malformed(let reason):
                let filename = item.receipt?.normalizedFilename ?? item.importID
                return ShareImportPreviewItem(
                    id: item.importID,
                    importID: item.importID,
                    filename: filename,
                    durationText: nil,
                    statusMessage: reason,
                    isActionable: false,
                    audioURL: nil
                )
            case .ready:
                guard let receipt = item.receipt,
                      let audioURL = item.audioFileURL else {
                    return ShareImportPreviewItem(
                        id: item.importID,
                        importID: item.importID,
                        filename: item.importID,
                        durationText: nil,
                        statusMessage: "The staged shared import is missing required metadata.",
                        isActionable: false,
                        audioURL: nil
                    )
                }

                let durationText: String
                do {
                    let inspection = try audioInspector.inspect(url: audioURL)
                    durationText = Self.durationFormatter.string(from: inspection.durationSeconds) ?? String(format: "%.1fs", inspection.durationSeconds)
                } catch {
                    return ShareImportPreviewItem(
                        id: item.importID,
                        importID: item.importID,
                        filename: receipt.normalizedFilename,
                        durationText: nil,
                        statusMessage: "The app could not decode the shared audio file to read its duration.",
                        isActionable: false,
                        audioURL: audioURL
                    )
                }

                return ShareImportPreviewItem(
                    id: item.importID,
                    importID: item.importID,
                    filename: receipt.normalizedFilename,
                    durationText: durationText,
                    statusMessage: "Ready to import",
                    isActionable: true,
                    audioURL: audioURL
                )
            }
        }

        items = mapped
        if mapped.isEmpty {
            isPresented = false
            headline = ""
            return
        }

        headline = mapped.count == 1 ? "Review Shared Recording" : "Shared Recordings"
        isPresented = true
    }

    func playPreview(importID: String) {
        guard let item = items.first(where: { $0.importID == importID }) else {
            return
        }

        guard let audioURL = item.audioURL else {
            errorMessage = item.statusMessage
            return
        }

        do {
            try previewPlayer.play(url: audioURL)
        } catch {
            errorMessage = "The app could not play a preview for this shared audio file."
        }
    }

    func useRecording(importID: String) {
        Task { @MainActor in
            let result = await pipeline.process(importID: importID)
            switch result.status {
            case .imported:
                errorMessage = nil
                scanInboxAndPresent()
            case let .failed(message):
                errorMessage = message
                scanInboxAndPresent()
            }
        }
    }

    func cancel() {
        previewPlayer.stop()
        isPresented = false
    }

    private static let durationFormatter: DateComponentsFormatter = {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = [.pad]
        return formatter
    }()
}
