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
            ZStack(alignment: .bottomTrailing) {
                CandlePlayerContainer(player: controller.player)
                    .frame(
                        width: geometry.size.width * 0.44,
                        height: geometry.size.height * 0.62
                    )
                    .scaleEffect(1.75, anchor: .bottomTrailing)
                    .offset(
                        x: geometry.size.width * 0.12,
                        y: geometry.size.height * 0.08
                    )
                    .blur(radius: isPassiveMode ? 20 : 24)
                    .opacity(isEnabled ? targetOpacity : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .clipped()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .clipped()
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
        isPassiveMode ? 0.06 : 0.025
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
    private static let bundledVideoName = "candle_background"
    private static let bundledVideoExtension = "mp4"
    private static let bundledVideoSubdirectory = "Sources/FamilyRosary/VIdeo"

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
