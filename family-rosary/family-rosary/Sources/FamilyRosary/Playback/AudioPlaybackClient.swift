import Foundation

protocol AudioPlaybackClient {
    func play(url: URL) async throws
    func play(url: URL, startSec: Double, endSec: Double) async throws
    func stop()
    var isPlaying: Bool { get }
}

extension AudioPlaybackClient {
    func play(url: URL, startSec: Double, endSec: Double) async throws {
        _ = startSec
        _ = endSec
        try await play(url: url)
    }
}
