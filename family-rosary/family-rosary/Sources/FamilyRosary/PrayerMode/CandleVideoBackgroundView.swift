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
        ZStack {
            if controller.shouldShowFallback || controller.player == nil {
                fallbackBackground
                    .opacity(isEnabled ? targetOpacity : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            if let player = controller.player, !controller.shouldShowFallback {
                CandlePlayerContainer(
                    player: player,
                    onLayout: controller.videoViewDidLayout(bounds:)
                )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .contrast(1.1)
                    .saturation(1.05)
                    .opacity(isEnabled ? targetOpacity : 0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .clipped()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .clipped()
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
        isPassiveMode ? 0.92 : 0.56
    }

    private var fallbackBackground: some View {
        RadialGradient(
            colors: [
                Color(hex: "C59A4D").opacity(0.28),
                Color(hex: "8F6730").opacity(0.12),
                .clear
            ],
            center: .bottomTrailing,
            startRadius: 16,
            endRadius: 280
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.clear)
        .clipped()
    }
}

private struct CandlePlayerContainer: UIViewRepresentable {
    let player: AVQueuePlayer?
    let onLayout: (CGRect) -> Void

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView(onLayout: onLayout)
        view.playerLayer.videoGravity = .resizeAspectFill
        view.setPlayer(player)
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.onLayout = onLayout
        uiView.setPlayer(player)
    }
}

private final class PlayerView: UIView {
    let playerLayer = AVPlayerLayer()
    var onLayout: (CGRect) -> Void

    init(onLayout: @escaping (CGRect) -> Void) {
        self.onLayout = onLayout
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        playerLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(playerLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setPlayer(_ player: AVQueuePlayer?) {
        guard playerLayer.player !== player else { return }
        playerLayer.player = player
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
        onLayout(bounds)
    }
}

@MainActor
final class CandleVideoBackgroundController: ObservableObject {
    private static let bundledVideoName = "candle_background"
    private static let bundledVideoExtension = "mp4"

    let player: AVQueuePlayer?
    @Published private(set) var shouldShowFallback = false

    private let looper: AVPlayerLooper?
    private var itemStatusCancellable: AnyCancellable?
    private var isEnabled = false
    private var isSceneActive = false
    private var isPassiveMode = true
    private var hasRenderableBounds = false

    init(bundle: Bundle = .main) {
        let directURL = Self.bundledVideoURL(in: bundle)

        guard let url = directURL ?? Self.fallbackVideoURL(in: bundle) else {
            print("Candle video not found in app bundle: expected \(Self.bundledVideoName).\(Self.bundledVideoExtension)")
            player = nil
            looper = nil
            shouldShowFallback = true
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

        itemStatusCancellable = item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self, weak item] status in
                self?.handleItemStatus(status, item: item)
            }
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

    func videoViewDidLayout(bounds: CGRect) {
        let hasBounds = bounds.width > 0 && bounds.height > 0
        guard hasRenderableBounds != hasBounds else { return }
        hasRenderableBounds = hasBounds
        refreshPlaybackState()
    }

    private func handleItemStatus(_ status: AVPlayerItem.Status, item: AVPlayerItem?) {
        switch status {
        case .unknown:
            break
        case .readyToPlay:
            break
        case .failed:
            shouldShowFallback = true
            let errorDescription = item?.error?.localizedDescription ?? "unknown AVPlayerItem failure"
            print("Candle video failed to load: \(errorDescription)")
            print("If playback fails despite valid bundle URL, re-encode candle_background.mp4 as H.264 .mp4, baseline/main profile, yuv420p, no HDR/HEVC.")
        @unknown default:
            shouldShowFallback = true
            print("Candle video failed to load: unknown item status \(status.rawValue)")
        }
    }

    private func refreshPlaybackState() {
        guard let player else { return }

        if isEnabled && isSceneActive && isPassiveMode && hasRenderableBounds && !shouldShowFallback {
            if player.timeControlStatus != .playing {
                player.play()
            }
        } else {
            player.pause()
        }
    }

    private static func bundledVideoURL(in bundle: Bundle) -> URL? {
        bundle.url(forResource: bundledVideoName, withExtension: bundledVideoExtension)
    }

    private static func fallbackVideoURL(in bundle: Bundle) -> URL? {
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
