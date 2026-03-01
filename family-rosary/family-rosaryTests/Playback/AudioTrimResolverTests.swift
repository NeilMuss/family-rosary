import XCTest
@testable import family_rosary

final class AudioTrimResolverTests: XCTestCase {
    func testPrefetchUsesCacheAfterFirstComputation() async {
        let sampleProvider = SampleProviderStub(
            samplesByPath: [
                "/tmp/a.m4a": (Array(repeating: Float(0), count: 100) + Array(repeating: Float(0.05), count: 200), 1_000.0)
            ]
        )
        let cache = AudioTrimCache()
        let resolver = AudioTrimResolver(
            sampleProvider: sampleProvider,
            trimmer: SilenceTrimmer(),
            cache: cache,
            config: SilenceTrimConfig(threshold: 0.02, minSoundMs: 60, padMs: 100, minClipMs: 120)
        )
        let url = URL(fileURLWithPath: "/tmp/a.m4a")

        await resolver.prefetch(url: url)
        await waitForCache(url: url, cache: cache)
        await resolver.prefetch(url: url)

        XCTAssertEqual(sampleProvider.loadCallCountSnapshot(), 1)
    }

    func testPrefetchCachesNilResults() async {
        let sampleProvider = SampleProviderStub(
            samplesByPath: [
                "/tmp/silent.m4a": (Array(repeating: Float(0), count: 600), 1_000.0)
            ]
        )
        let cache = AudioTrimCache()
        let resolver = AudioTrimResolver(
            sampleProvider: sampleProvider,
            trimmer: SilenceTrimmer(),
            cache: cache,
            config: .default
        )
        let url = URL(fileURLWithPath: "/tmp/silent.m4a")

        await resolver.prefetch(url: url)
        await waitForCache(url: url, cache: cache)
        await resolver.prefetch(url: url)

        XCTAssertEqual(sampleProvider.loadCallCountSnapshot(), 1)
        let cached = await cache.get(url)
        XCTAssertNotNil(cached)
        XCTAssertNil(cached!)
    }

    private func waitForCache(url: URL, cache: AudioTrimCache) async {
        for _ in 0..<50 {
            if await cache.get(url) != nil {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTFail("Expected trim to be cached")
    }
}

private final class SampleProviderStub: AudioSampleProvider, @unchecked Sendable {
    let samplesByPath: [String: (samples: [Float], sampleRate: Double)]

    private let lock = NSLock()
    private var loadCallCount = 0

    init(samplesByPath: [String: (samples: [Float], sampleRate: Double)]) {
        self.samplesByPath = samplesByPath
    }

    nonisolated func loadMonoSamples(from url: URL) throws -> (samples: [Float], sampleRate: Double) {
        lock.lock()
        loadCallCount += 1
        lock.unlock()

        if let value = samplesByPath[url.path] {
            return value
        }

        throw NSError(domain: "SampleProviderStub", code: 1)
    }

    nonisolated func loadCallCountSnapshot() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return loadCallCount
    }
}
