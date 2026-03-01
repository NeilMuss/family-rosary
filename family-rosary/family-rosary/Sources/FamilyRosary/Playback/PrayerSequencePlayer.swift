import Foundation

protocol PrayerSequencePlaying {
    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void,
        onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    ) async throws
    func stop()
}

extension PrayerSequencePlaying {
    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void
    ) async throws {
        try await play(
            steps: steps,
            onPromptChanged: onPromptChanged,
            onDebugStatusChanged: nil
        )
    }
}

final class PrayerSequencePlayer: PrayerSequencePlaying {
    private let playback: AudioPlaybackClient
    private let sleeper: Sleeper
    private let utteranceListener: UtteranceListener?
    private let clipCatalog: PrayerClipCatalog?
    private var onPromptChanged: ((PrayerPrompt?) -> Void)?
    #if DEBUG
    private var onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    #endif
    private var stopped = false

    init(
        playback: AudioPlaybackClient,
        sleeper: Sleeper,
        utteranceListener: UtteranceListener? = nil,
        clipCatalog: PrayerClipCatalog? = nil
    ) {
        self.playback = playback
        self.sleeper = sleeper
        self.utteranceListener = utteranceListener
        self.clipCatalog = clipCatalog
    }

    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void,
        onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    ) async throws {
        stopped = false
        self.onPromptChanged = onPromptChanged
        #if DEBUG
        self.onDebugStatusChanged = onDebugStatusChanged
        #endif
        defer {
            self.onPromptChanged?(nil)
            self.onPromptChanged = nil
            #if DEBUG
            emitDebug(stepSummary: "Done", phase: .idle)
            self.onDebugStatusChanged = nil
            #endif
        }

        for step in steps {
            if stopped { return }
            self.onPromptChanged?(step.prompt)
            #if DEBUG
            emitStepDebug(step)
            #endif
            try await run(step: step)
        }
    }

    private func run(step: PrayerSequenceStep) async throws {
        switch step {
        case .play(let asset, _):
            try await play(asset: asset)
        case .pause(let ms, _):
            await sleeper.sleep(ms: ms)
        case .waitForUtterance(let config, _):
            guard let utteranceListener else {
                #if DEBUG
                emitDebug(stepSummary: "Step: WAIT", phase: .failed("Interactive utterance listener is not configured."))
                #endif
                throw NSError(
                    domain: "PrayerSequencePlayer",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Interactive utterance listener is not configured."]
                )
            }
            #if DEBUG
            try await utteranceListener.waitForUtterance(config: config, onPhaseChanged: { [weak self] phase in
                self?.emitDebug(stepSummary: "Step: WAIT", phase: phase)
            })
            #else
            try await utteranceListener.waitForUtterance(config: config, onPhaseChanged: nil)
            #endif
        }
    }

    func stop() {
        stopped = true
        playback.stop()
        onPromptChanged?(nil)
        #if DEBUG
        emitDebug(stepSummary: "Stopped", phase: .idle)
        #endif
    }

    private func play(asset: AudioAssetRef) async throws {
        let clip = clipCatalog?.clip(id: asset.id)
        #if DEBUG
        emitDebug(stepSummary: "PLAY assetID=\(asset.id)", phase: .idle)
        #endif

        guard let clip else {
            #if DEBUG
            emitDebug(stepSummary: "PLAYCLIP \(asset.id) full (catalog miss)", phase: .idle)
            #endif
            try await playback.play(url: asset.url)
            return
        }

        #if DEBUG
        emitDebug(
            stepSummary: String(format: "PLAYCLIP %@ start=%.2f end=%.2f", asset.id, clip.startSec, clip.endSec),
            phase: .idle
        )
        #endif
        try await playback.play(url: asset.url, startSec: clip.startSec, endSec: clip.endSec)
    }

    #if DEBUG
    private func emitStepDebug(_ step: PrayerSequenceStep) {
        func summary(base: String, prompt: PrayerPrompt?) -> String {
            guard let prompt else { return base }
            return "\(base) (\(prompt.text))"
        }

        switch step {
        case .play(_, let prompt):
            emitDebug(stepSummary: summary(base: "Step: PLAY", prompt: prompt), phase: .idle)
        case .pause(_, let prompt):
            emitDebug(stepSummary: summary(base: "Step: PAUSE", prompt: prompt), phase: .idle)
        case .waitForUtterance(_, let prompt):
            emitDebug(stepSummary: summary(base: "Step: WAIT", prompt: prompt), phase: .idle)
        }
    }

    private func emitDebug(stepSummary: String, phase: UtteranceDebugPhase) {
        onDebugStatusChanged?(PrayDebugStatus(stepSummary: stepSummary, listenerPhase: phase))
    }
    #endif
}
