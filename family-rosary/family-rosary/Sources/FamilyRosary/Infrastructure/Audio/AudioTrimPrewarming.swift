import Foundation

protocol AudioTrimPrewarming: Sendable {
    func prewarm(urls: [URL], onLog: (@Sendable (String) -> Void)?) async
}

extension AudioTrimResolver: AudioTrimPrewarming {}
