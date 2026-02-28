import Foundation

protocol AudioPlaybackClient {
    func play(url: URL) async throws
    func stop()
    var isPlaying: Bool { get }
}
