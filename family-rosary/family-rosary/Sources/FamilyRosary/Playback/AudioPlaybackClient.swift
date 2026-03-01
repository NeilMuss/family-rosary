import Foundation

protocol AudioPlaybackClient {
    func play(url: URL) async throws
    func play(url: URL, segment: TrimRange?) async throws
    func stop()
    var isPlaying: Bool { get }
}

extension AudioPlaybackClient {
    func play(url: URL, segment: TrimRange?) async throws {
        _ = segment
        try await play(url: url)
    }
}
