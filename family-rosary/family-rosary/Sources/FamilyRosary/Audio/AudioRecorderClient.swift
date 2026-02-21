import Foundation

protocol AudioRecorderClient {
    func startRecording(to url: URL) throws
    func stopRecording() throws
    func play(url: URL) throws
    func stopPlayback()
    var isRecording: Bool { get }
    var isPlaying: Bool { get }
}
