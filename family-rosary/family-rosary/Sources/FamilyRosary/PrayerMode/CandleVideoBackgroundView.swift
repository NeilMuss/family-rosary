import SwiftUI
import AVFoundation
import Combine
import UIKit

struct CandleVideoBackgroundView: View {
    @StateObject private var controller = CandleVideoBackgroundController()

    let isEnabled: Bool
    let isPassiveMode: Bool

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                CandlePlayerContainer(player: controller.player)
                    .frame(
                        width: geometry.size.width,
                        height: geometry.size.height
                    )
                    .blur(radius: 0)
                    .opacity(isEnabled ? targetOpacity : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .onAppear {
                print("CANDLE_DEBUG | geometry | size=\(geometry.size.width)x\(geometry.size.height)")
            }
        }
        .onAppear {
            controller.setEnabled(isEnabled)
            controller.setPassiveMode(isPassiveMode)
            controller.setSceneActive(scenePhase == .active)
        }
        .onDisappear {
            controller.stop()
        }
        .onChange(of: isEnabled) { enabled in
            controller.setEnabled(enabled)
        }
        .onChange(of: isPassiveMode) { passive in
            controller.setPassiveMode(passive)
        }
        .onChange(of: scenePhase) { newPhase in
            controller.setSceneActive(newPhase == .active)
        }
        .animation(.easeInOut(duration: 0.5), value: isEnabled)
        .animation(.easeInOut(duration: 0.5), value: isPassiveMode)
    }

    private var targetOpacity: Double {
        isPassiveMode ? 0.8 : 0.4
    }
}

private struct CandlePlayerContainer: UIViewRepresentable {
    let player: AVQueuePlayer?

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        print("CANDLE_DEBUG | makeUIView | playerAssigned=\(player != nil)")
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
        print(
            "CANDLE_DEBUG | updateUIView | bounds=\(uiView.bounds.width)x\(uiView.bounds.height) attached=\(uiView.window != nil) layerBounds=\(uiView.playerLayer.bounds.width)x\(uiView.playerLayer.bounds.height)"
        )
    }
}

private final class PlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}

@MainActor
final class CandleVideoBackgroundController: ObservableObject {
    private static let bundledVideoName = "candle_background"
    private static let bundledVideoExtension = "mp4"
    private static let bundledVideoSubdirectory = "Sources/FamilyRosary/VIdeo"

    let player: AVQueuePlayer?

    private let looper: AVPlayerLooper?
    private var isEnabled = false
    private var isSceneActive = false
    private var isPassiveMode = true

    init(bundle: Bundle = .main) {
        let mp4URLs = Self.allMP4URLs(in: bundle)
        for url in mp4URLs {
            print("CANDLE_DEBUG | bundleMP4:", url.absoluteString)
        }
        let directURL = bundle.url(
            forResource: Self.bundledVideoName,
            withExtension: Self.bundledVideoExtension
        )
        print("CANDLE_DEBUG | directLookup | url=\(directURL?.absoluteString ?? "nil")")

        guard let url = Self.videoURL(in: bundle) else {
            print("CANDLE_DEBUG | resolvedURL | nil")
            player = nil
            looper = nil
            return
        }

        print("CANDLE_DEBUG | resolvedURL | url=\(url.absoluteString)")
        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        player = queuePlayer
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
        print("CANDLE_DEBUG | playerCreated | success=\(player != nil)")
        print("CANDLE_DEBUG | looperCreated | success=\(looper != nil)")
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        refreshPlaybackState()
    }

    func setSceneActive(_ active: Bool) {
        isSceneActive = active
        refreshPlaybackState()
    }

    func setPassiveMode(_ passiveMode: Bool) {
        isPassiveMode = passiveMode
        refreshPlaybackState()
    }

    func stop() {
        player?.pause()
        player?.seek(to: .zero)
    }

    private func refreshPlaybackState() {
        guard let player else { return }

        if isEnabled && isSceneActive && isPassiveMode {
            if player.timeControlStatus != .playing {
                player.play()
                print("CANDLE_DEBUG | playCalled | rate=\(player.rate)")
            }
        } else {
            player.pause()
            print("CANDLE_DEBUG | pauseCalled | enabled=\(isEnabled) scene=\(isSceneActive) passive=\(isPassiveMode)")
        }
    }

    private static func allMP4URLs(in bundle: Bundle) -> [URL] {
        let resourceURL = bundle.resourceURL ?? bundle.bundleURL
        let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil)
        var urls: [URL] = []

        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "mp4" {
                urls.append(url)
            }
        }

        return urls
    }

    private static func videoURL(in bundle: Bundle) -> URL? {
        let directMatches = [
            bundle.url(
                forResource: bundledVideoName,
                withExtension: bundledVideoExtension,
                subdirectory: bundledVideoSubdirectory
            ),
            bundle.url(forResource: bundledVideoName, withExtension: bundledVideoExtension)
        ]

        if let directMatch = directMatches.compactMap({ $0 }).first {
            return directMatch
        }

        let resourceURL = bundle.resourceURL ?? bundle.bundleURL
        let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil)

        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent.lowercased() == "\(bundledVideoName).\(bundledVideoExtension)" {
                return url
            }
        }

        return nil
    }
}
