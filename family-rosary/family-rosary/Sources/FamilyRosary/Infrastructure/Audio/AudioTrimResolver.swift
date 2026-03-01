import AVFoundation
import Foundation

actor AudioTrimResolver {
    private var inFlight: [URL: Task<PrefetchOutcome, Never>] = [:]

    let cache: AudioTrimCache
    let provider: AudioSampleProvider
    let trimmer: AudioSilenceTrimmer
    let config: SilenceTrimConfig

    init(
        sampleProvider: AudioSampleProvider,
        trimmer: AudioSilenceTrimmer,
        cache: AudioTrimCache,
        config: SilenceTrimConfig
    ) {
        self.provider = sampleProvider
        self.trimmer = trimmer
        self.cache = cache
        self.config = config
    }

    func getCachedTrim(for url: URL) async -> TrimRange?? {
        await cache.get(url)
    }

    func prewarm(urls: [URL], onLog: (@Sendable (String) -> Void)? = nil) async {
        let uniqueURLs = Array(Set(urls))
        guard !uniqueURLs.isEmpty else { return }

        await withTaskGroup(of: Void.self) { group in
            for url in uniqueURLs {
                group.addTask { [weak self] in
                    guard let self else { return }
                    let outcome = await self.ensureOutcome(url: url)
                    await self.cache.set(outcome.trim, for: url)
                    await self.clearInFlight(url)

                    #if DEBUG
                    if let onLog {
                        onLog(Self.logMessage(url: url, outcome: outcome))
                    }
                    #endif
                }
            }
        }
    }

    func prefetch(url: URL, onLog: (@Sendable (String) -> Void)? = nil) async {
        #if DEBUG
        let bypassCache = Self.shouldBypassCache
        #else
        let bypassCache = false
        #endif

        if !bypassCache, let cached = await cache.get(url) {
            #if DEBUG
            if let onLog {
                onLog(Self.cachedLogMessage(url: url, trim: cached))
            }
            #endif
            return
        }

        let task = await ensureTask(url: url)

        Task.detached { [weak self] in
            let outcome = await task.value
            guard let self else { return }
            await self.cache.set(outcome.trim, for: url)
            await self.clearInFlight(url)

            #if DEBUG
            if let onLog {
                onLog(Self.logMessage(url: url, outcome: outcome))
            }
            #endif
        }
    }

    private func clearInFlight(_ url: URL) {
        inFlight[url] = nil
    }

    private func ensureOutcome(url: URL) async -> PrefetchOutcome {
        let task = await ensureTask(url: url)
        return await task.value
    }

    private func ensureTask(url: URL) -> Task<PrefetchOutcome, Never> {
        if let task = inFlight[url] {
            return task
        }

        let task = Task.detached(priority: .utility) { [provider, trimmer, config] in
            do {
                let loaded = try provider.loadMonoSamples(from: url)
                let durationFromFile = Self.fileDurationSeconds(for: url)
                let diagnostics = Self.makeDiagnostics(
                    samples: loaded.samples,
                    sampleRate: loaded.sampleRate,
                    durationOverride: durationFromFile
                )
                let trim = trimmer.computeTrim(
                    samples: loaded.samples,
                    sampleRate: loaded.sampleRate,
                    config: config
                )
                return PrefetchOutcome(trim: trim, diagnostics: diagnostics, errorDescription: nil)
            } catch {
                let errorDescription = Self.describeError(error, for: url)
                return PrefetchOutcome(trim: nil, diagnostics: nil, errorDescription: errorDescription)
            }
        }
        inFlight[url] = task
        return task
    }

    private struct PrefetchOutcome {
        let trim: TrimRange?
        let diagnostics: TrimDiagnostics?
        let errorDescription: String?
    }

    private struct TrimDiagnostics {
        let maxAbsSample: Float
        let totalDurationSec: Double
        let headAvgAbs: Float
        let tailAvgAbs: Float
    }

    #if DEBUG
    nonisolated private static var shouldBypassCache: Bool {
        ProcessInfo.processInfo.environment["TRIM_DEBUG_BYPASS_CACHE"] == "1"
    }

    nonisolated private static func makeDiagnostics(
        samples: [Float],
        sampleRate: Double,
        durationOverride: Double?
    ) -> TrimDiagnostics {
        let maxAbs = samples.reduce(0) { max($0, abs($1)) }
        let derivedDuration = sampleRate > 0 ? Double(samples.count) / sampleRate : 0
        let edgeWindowSamples = max(1, Int(sampleRate * 0.5))
        let headAvg = averageAbs(samples.prefix(edgeWindowSamples))
        let tailAvg = averageAbs(samples.suffix(edgeWindowSamples))
        return TrimDiagnostics(
            maxAbsSample: maxAbs,
            totalDurationSec: durationOverride ?? derivedDuration,
            headAvgAbs: headAvg,
            tailAvgAbs: tailAvg
        )
    }

    nonisolated private static func averageAbs<S: Sequence>(_ samples: S) -> Float where S.Element == Float {
        var count: Int = 0
        var total: Float = 0
        for sample in samples {
            total += abs(sample)
            count += 1
        }
        guard count > 0 else { return 0 }
        return total / Float(count)
    }

    nonisolated private static func fileDurationSeconds(for url: URL) -> Double? {
        guard let file = try? AVAudioFile(forReading: url) else { return nil }
        let sampleRate = file.processingFormat.sampleRate
        guard sampleRate > 0 else { return nil }
        return Double(file.length) / sampleRate
    }

    nonisolated private static func cachedLogMessage(url: URL, trim: TrimRange?) -> String {
        guard let trim else {
            return "TRIM \(url.lastPathComponent) -> none [cached]"
        }

        return String(
            format: "TRIM %@ -> start=%.2f end=%.2f [cached]",
            url.lastPathComponent,
            trim.startSec,
            trim.endSec
        )
    }

    nonisolated private static func describeError(_ error: Error, for url: URL) -> String {
        let nsError = error as NSError
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: url.path)
        let sizeBytes = ((try? fm.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value) ?? -1

        var fileDetails = "open_failed"
        if let file = try? AVAudioFile(forReading: url) {
            fileDetails = String(
                format: "frames=%lld fileFormat={%@} processingFormat={%@}",
                file.length,
                describe(format: file.fileFormat),
                describe(format: file.processingFormat)
            )
        }

        let providerDetails = nsError.userInfo
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: ",")

        return String(
            format: "file=%@ exists=%@ size=%lld %@ errDomain=%@ errCode=%ld errUserInfo={%@}",
            url.lastPathComponent,
            String(exists),
            sizeBytes,
            fileDetails,
            nsError.domain,
            nsError.code,
            providerDetails
        )
    }

    nonisolated private static func describe(format: AVAudioFormat) -> String {
        let commonFormat: String
        switch format.commonFormat {
        case .pcmFormatFloat32:
            commonFormat = "float32"
        case .pcmFormatFloat64:
            commonFormat = "float64"
        case .pcmFormatInt16:
            commonFormat = "int16"
        case .pcmFormatInt32:
            commonFormat = "int32"
        case .otherFormat:
            commonFormat = "other"
        @unknown default:
            commonFormat = "unknown"
        }

        return String(
            format: "sr=%.2f ch=%u fmt=%@ interleaved=%@",
            format.sampleRate,
            format.channelCount,
            commonFormat,
            String(format.isInterleaved)
        )
    }

    nonisolated private static func logMessage(url: URL, outcome: PrefetchOutcome) -> String {
        if let errorDescription = outcome.errorDescription {
            return "TRIM \(url.lastPathComponent) -> error(\(errorDescription))"
        }

        let maxAbs = outcome.diagnostics?.maxAbsSample ?? 0
        let duration = outcome.diagnostics?.totalDurationSec ?? 0
        let headAvg = outcome.diagnostics?.headAvgAbs ?? 0
        let tailAvg = outcome.diagnostics?.tailAvgAbs ?? 0

        guard let trim = outcome.trim else {
            return String(
                format: "TRIM %@ -> none (max=%.3f dur=%.1fs head=%.3f tail=%.3f)",
                url.lastPathComponent,
                maxAbs,
                duration,
                headAvg,
                tailAvg
            )
        }

        return String(
            format: "TRIM %@ -> start=%.2f end=%.2f (max=%.3f dur=%.1fs head=%.3f tail=%.3f)",
            url.lastPathComponent,
            trim.startSec,
            trim.endSec,
            maxAbs,
            duration,
            headAvg,
            tailAvg
        )
    }
    #endif
}
