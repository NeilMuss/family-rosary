import SwiftUI
import AVFoundation
import UIKit

struct CandleVideoBackgroundView: View {
    @StateObject private var controller = CandleVideoBackgroundController()

    let isEnabled: Bool
    let isPassiveMode: Bool

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        CandlePlayerContainer(player: controller.player)
            .blur(radius: isPassiveMode ? 16 : 20)
            .opacity(isEnabled ? targetOpacity : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
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
        isPassiveMode ? 0.09 : 0.05
    }
}

private struct CandlePlayerContainer: UIViewRepresentable {
    let player: AVQueuePlayer?

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.playerLayer.player = player
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
    let player: AVQueuePlayer?

    private let looper: AVPlayerLooper?
    private var isEnabled = false
    private var isSceneActive = false
    private var isPassiveMode = true

    init(bundle: Bundle = .main) {
        guard let url = Self.videoURL(in: bundle) else {
            player = nil
            looper = nil
            return
        }

        let asset = AVAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        let queuePlayer = AVQueuePlayer()
        queuePlayer.isMuted = true
        queuePlayer.actionAtItemEnd = .none
        queuePlayer.preventsDisplaySleepDuringVideoPlayback = false
        queuePlayer.automaticallyWaitsToMinimizeStalling = true
        player = queuePlayer
        looper = AVPlayerLooper(player: queuePlayer, templateItem: item)
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
            }
        } else {
            player.pause()
        }
    }

    private static func videoURL(in bundle: Bundle) -> URL? {
        let directMatches = [
            bundle.url(forResource: "Candle", withExtension: "MOV", subdirectory: "Sources/FamilyRosary/VIdeo"),
            bundle.url(forResource: "Candle", withExtension: "mov", subdirectory: "Sources/FamilyRosary/VIdeo"),
            bundle.url(forResource: "Candle", withExtension: "MOV"),
            bundle.url(forResource: "Candle", withExtension: "mov")
        ]

        if let directMatch = directMatches.compactMap({ $0 }).first {
            return directMatch
        }

        let resourceURL = bundle.resourceURL ?? bundle.bundleURL
        let enumerator = FileManager.default.enumerator(at: resourceURL, includingPropertiesForKeys: nil)

        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent.lowercased() == "candle.mov" {
                return url
            }
        }

        return nil
    }
}
