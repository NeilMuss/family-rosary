import Foundation

// Intentional migration seam: these adapters let existing app models be expressed in
// domain language without changing current storage, playback, or UI call sites yet.

extension PrayerName {
    var domainPrayerKey: PrayerKey {
        switch self {
        case .apostlesCreed:
            return .apostlesCreed
        case .ourFather:
            return .ourFather
        case .hailMary:
            return .hailMary
        case .gloryBe:
            return .gloryBe
        case .fatima:
            return .fatimaPrayer
        case .hailHolyQueen:
            return .hailHolyQueen
        }
    }
}

extension PrayerKey {
    init(_ prayerName: PrayerName) {
        self = prayerName.domainPrayerKey
    }
}

extension AudioRecordingPart {
    var domainPrayerLineKey: PrayerLineKey {
        switch self {
        case .apostlesCreed:
            return PrayerLineKey(prayer: .apostlesCreed, role: .full)
        case .ourFatherLead:
            return PrayerLineKey(prayer: .ourFather, role: .lead)
        case .ourFatherResponse:
            return PrayerLineKey(prayer: .ourFather, role: .respond)
        case .hailMaryLead:
            return PrayerLineKey(prayer: .hailMary, role: .lead)
        case .hailMaryResponse:
            return PrayerLineKey(prayer: .hailMary, role: .respond)
        case .gloryBeLead:
            return PrayerLineKey(prayer: .gloryBe, role: .lead)
        case .gloryBeResponse:
            return PrayerLineKey(prayer: .gloryBe, role: .respond)
        case .fatima:
            return PrayerLineKey(prayer: .fatimaPrayer, role: .full)
        case .hailHolyQueenLead:
            return PrayerLineKey(prayer: .hailHolyQueen, role: .lead)
        case .hailHolyQueenResponse:
            return PrayerLineKey(prayer: .hailHolyQueen, role: .respond)
        }
    }
}

extension ImportSlot {
    var domainPrayerLineKey: PrayerLineKey {
        audioPart.domainPrayerLineKey
    }
}

extension RecordingKey {
    var domainPrayerLineKey: PrayerLineKey {
        PrayerLineKey(prayer: prayer.domainPrayerKey, role: part.domainPrayerRole)
    }
}

extension PrayerPart {
    var domainPrayerRole: PrayerRole {
        switch self {
        case .lead:
            return .lead
        case .response:
            return .respond
        case .full:
            return .full
        }
    }
}

extension PrayerPartner {
    private static let builtInCompanionIDs: Set<String> = ["dad", "mom"]

    var domainVoiceProfile: VoiceProfile {
        let kind: VoiceProfileKind = Self.builtInCompanionIDs.contains(id) ? .builtInCompanion : .personal
        return VoiceProfile(
            id: VoiceProfileID(rawValue: id),
            displayName: displayName,
            kind: kind
        )
    }
}

extension TrimSuggestion {
    var domainTrimDefinition: TrimDefinition {
        TrimDefinition(
            suggestedStart: startTime,
            suggestedEnd: endTime,
            userStart: nil,
            userEnd: nil
        )
    }
}

extension PrayerClip {
    var domainTrimDefinition: TrimDefinition {
        TrimDefinition(
            suggestedStart: startSec,
            suggestedEnd: endSec,
            userStart: nil,
            userEnd: nil
        )
    }

    var domainRecordingAsset: RecordingAsset? {
        guard let key = RecordingKey(playbackToken: prayer)?.domainPrayerLineKey else {
            return nil
        }

        return RecordingAsset(
            id: RecordingAssetID(rawValue: id),
            prayerLineKey: key,
            ownerProfileID: VoiceProfileID(rawValue: person),
            source: .bundled,
            trim: domainTrimDefinition,
            status: .ready,
            storageKey: fileName
        )
    }
}

extension FinalisedImportedRecording {
    var domainRecordingAsset: RecordingAsset {
        RecordingAsset(
            id: RecordingAssetID(rawValue: id),
            prayerLineKey: prayerPart.domainPrayerLineKey,
            ownerProfileID: VoiceProfileID(rawValue: partnerID),
            source: .importedShare,
            trim: TrimDefinition(
                suggestedStart: 0,
                suggestedEnd: durationSeconds,
                userStart: nil,
                userEnd: nil
            ),
            status: .ready,
            storageKey: libraryFileURL.path
        )
    }
}

extension PlaybackSegment {
    init(asset: RecordingAsset) {
        self.init(
            prayerLineKey: asset.prayerLineKey,
            recordingAssetID: asset.id,
            startTime: asset.trim.effectiveStart,
            endTime: asset.trim.effectiveEnd,
            storageKey: asset.storageKey
        )
    }
}
