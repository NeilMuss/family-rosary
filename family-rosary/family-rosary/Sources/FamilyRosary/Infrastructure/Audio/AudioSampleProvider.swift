import Foundation

protocol AudioSampleProvider: Sendable {
    nonisolated func loadMonoSamples(from url: URL) throws -> (samples: [Float], sampleRate: Double)
}
