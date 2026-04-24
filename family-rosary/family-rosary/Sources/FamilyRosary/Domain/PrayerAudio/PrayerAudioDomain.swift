import Foundation

enum PrayerKey: String, CaseIterable, Hashable, Codable, Sendable {
    case apostlesCreed
    case ourFather
    case hailMary
    case gloryBe
    case fatimaPrayer
    case hailHolyQueenOpening
    case hailHolyQueenResponse
    case hailHolyQueenClosing
    case hailHolyQueen
}

extension PrayerKey {
    static func == (lhs: PrayerKey, rhs: PrayerKey) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

enum PrayerRole: String, Hashable, Codable, Sendable {
    case lead
    case respond
    case full
}

extension PrayerRole {
    static func == (lhs: PrayerRole, rhs: PrayerRole) -> Bool {
        lhs.rawValue == rhs.rawValue
    }
}

/// Domain identifier for a specific prayer line (prayer + role).
/// Intentionally nonisolated and Sendable for pure domain/application logic.
struct PrayerLineKey: Hashable, Codable, Sendable {
    let prayer: PrayerKey
    let role: PrayerRole
}

extension PrayerLineKey {
    static func == (lhs: PrayerLineKey, rhs: PrayerLineKey) -> Bool {
        lhs.prayer == rhs.prayer && lhs.role == rhs.role
    }
}

struct VoiceProfileID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum VoiceProfileKind: String, Hashable, Codable {
    case builtInCompanion
    case personal
}

struct VoiceProfile: Hashable, Codable {
    let id: VoiceProfileID
    let displayName: String
    let kind: VoiceProfileKind

    var isBuiltIn: Bool {
        kind == .builtInCompanion
    }
}

struct RecordingAssetID: Hashable, Codable, RawRepresentable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }
}

enum RecordingSource: String, Hashable, Codable {
    case bundled
    case importedShare
    case importedFile
    case recordedInApp
}

enum RecordingFailure: String, Hashable, Codable {
    case missingAsset
    case invalidMetadata
    case unknown
}

enum RecordingStatus: Hashable, Codable {
    case staged
    case ready
    case failed(reason: RecordingFailure)

    private enum CodingKeys: String, CodingKey {
        case kind
        case reason
    }

    private enum Kind: String, Codable {
        case staged
        case ready
        case failed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .kind)
        switch kind {
        case .staged:
            self = .staged
        case .ready:
            self = .ready
        case .failed:
            self = .failed(reason: try container.decode(RecordingFailure.self, forKey: .reason))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .staged:
            try container.encode(Kind.staged, forKey: .kind)
        case .ready:
            try container.encode(Kind.ready, forKey: .kind)
        case .failed(let reason):
            try container.encode(Kind.failed, forKey: .kind)
            try container.encode(reason, forKey: .reason)
        }
    }
}

struct TrimDefinition: Hashable, Codable {
    let suggestedStart: Double?
    let suggestedEnd: Double?
    let userStart: Double?
    let userEnd: Double?

    var effectiveStart: Double {
        userStart ?? suggestedStart ?? 0
    }

    var effectiveEnd: Double {
        userEnd ?? suggestedEnd ?? 0
    }
}

struct RecordingAsset: Hashable, Codable {
    let id: RecordingAssetID
    let prayerLineKey: PrayerLineKey
    let ownerProfileID: VoiceProfileID
    let source: RecordingSource
    let trim: TrimDefinition
    let status: RecordingStatus
    let storageKey: String?
}

struct PlaybackSegment: Hashable, Codable {
    let prayerLineKey: PrayerLineKey
    let recordingAssetID: RecordingAssetID
    let startTime: Double
    let endTime: Double
    let storageKey: String?
}

struct PlaybackPlan: Hashable, Codable {
    let segments: [PlaybackSegment]
}

#if DEBUG
extension RecordingAsset: CustomDebugStringConvertible {
    var debugDescription: String {
        "RecordingAsset(id: \(id.rawValue), prayer: \(prayerLineKey.prayer.rawValue), role: \(prayerLineKey.role.rawValue), owner: \(ownerProfileID.rawValue), source: \(source.rawValue), status: \(status))"
    }
}
#endif
