import Foundation

/// Minimal application-layer lookup used by the transitional playback planner.
/// This is intentionally narrow so existing storage and resolver code can be adapted
/// without changing production call sites yet.
protocol RecordingAssetLookup {
    /// Returns a domain recording asset for the requested prayer line and owner profile.
    /// Only ready assets are meaningful to the planner.
    func findAsset(ownerProfileID: VoiceProfileID, prayerLineKey: PrayerLineKey) -> RecordingAsset?
}

/// Pure application use case that expresses the current playback selection rules in domain terms.
/// This use case is additive and does not replace the existing playback resolver in production yet.
struct BuildPlaybackPlanUseCase {
    /// Transitional error so comparison tests and future migration call sites can detect
    /// when neither the preferred nor fallback profile has a playable asset.
    enum Error: Swift.Error, Equatable {
        case missingReadyAsset(prayerLineKey: PrayerLineKey)
    }

    private let lookup: RecordingAssetLookup

    init(lookup: RecordingAssetLookup) {
        self.lookup = lookup
    }

    func execute(
        prayerSequence: [PrayerLineKey],
        preferredProfileID: VoiceProfileID,
        fallbackProfileID: VoiceProfileID
    ) throws -> PlaybackPlan {
        let segments = try prayerSequence.map { prayerLineKey in
            let asset = try resolveAsset(
                prayerLineKey: prayerLineKey,
                preferredProfileID: preferredProfileID,
                fallbackProfileID: fallbackProfileID
            )
            return PlaybackSegment(asset: asset)
        }

        return PlaybackPlan(segments: segments)
    }

    private func resolveAsset(
        prayerLineKey: PrayerLineKey,
        preferredProfileID: VoiceProfileID,
        fallbackProfileID: VoiceProfileID
    ) throws -> RecordingAsset {
        if let preferred = lookup.findAsset(ownerProfileID: preferredProfileID, prayerLineKey: prayerLineKey),
           preferred.status == .ready {
            return preferred
        }

        if let fallback = lookup.findAsset(ownerProfileID: fallbackProfileID, prayerLineKey: prayerLineKey),
           fallback.status == .ready {
            return fallback
        }

        throw Error.missingReadyAsset(prayerLineKey: prayerLineKey)
    }
}
