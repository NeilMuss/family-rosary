import Foundation

enum PrayerPart: String, Hashable, Codable {
    case lead
    case closingLead
    case response
    case full
}

struct RecordingKey: Hashable {
    let prayer: PrayerName
    let part: PrayerPart

    init(prayer: PrayerName, part: PrayerPart) {
        self.prayer = prayer
        self.part = part
    }

    init?(playbackToken: String) {
        switch playbackToken {
        case "apostles_creed_lead":
            self.init(prayer: .apostlesCreed, part: .lead)
        case "apostles_creed_response":
            self.init(prayer: .apostlesCreed, part: .response)
        case "our_father_lead":
            self.init(prayer: .ourFather, part: .lead)
        case "our_father_response":
            self.init(prayer: .ourFather, part: .response)
        case "hail_lead":
            self.init(prayer: .hailMary, part: .lead)
        case "hail_response":
            self.init(prayer: .hailMary, part: .response)
        case "glory_be_lead":
            self.init(prayer: .gloryBe, part: .lead)
        case "glory_be_response":
            self.init(prayer: .gloryBe, part: .response)
        case "fatima":
            self.init(prayer: .fatima, part: .full)
        case "hail_holy_queen_lead":
            self.init(prayer: .hailHolyQueen, part: .lead)
        case "hail_holy_queen_response":
            self.init(prayer: .hailHolyQueen, part: .response)
        case "hail_holy_queen_closing":
            self.init(prayer: .hailHolyQueen, part: .closingLead)
        default:
            return nil
        }
    }

    var debugLabel: String {
        "\(prayer.rawValue).\(part.rawValue)"
    }

    var candidateFilenameTokens: [String] {
        switch (prayer, part) {
        case (.apostlesCreed, .lead):
            return ["apostles_creed_lead", "apostles_creed"]
        case (.apostlesCreed, .response):
            return ["apostles_creed_response", "apostles_creed"]
        case (.apostlesCreed, .full):
            return ["apostles_creed"]
        case (.ourFather, .lead):
            return ["our_father_lead"]
        case (.ourFather, .response):
            return ["our_father_response"]
        case (.hailMary, .lead):
            return ["hail_lead"]
        case (.hailMary, .response):
            return ["hail_response"]
        case (.gloryBe, .lead):
            return ["glory_be_lead"]
        case (.gloryBe, .response):
            return ["glory_be_response"]
        case (.fatima, .full):
            return ["fatima"]
        case (.hailHolyQueen, .lead):
            return ["hail_holy_queen_lead"]
        case (.hailHolyQueen, .closingLead):
            return ["hail_holy_queen_closing", "hail_holy_queen_lead"]
        case (.hailHolyQueen, .response):
            return ["hail_holy_queen_response"]
        default:
            return []
        }
    }
}

struct Recording: Equatable {
    let partnerID: String
    let key: RecordingKey
    let fileURL: URL
}

protocol RecordingStore {
    func find(partnerID: String, key: RecordingKey) -> Recording?
}

func resolveRecording(
    partnerID: String,
    key: RecordingKey,
    recordingStore: RecordingStore,
    defaultPartnerID: String,
    onMissingDefault: (String) -> Recording = { message in
        fatalError(message)
    }
) -> Recording {
    if let partnerRecording = recordingStore.find(partnerID: partnerID, key: key) {
        DebugLog.shared.log("RESOLVE_RECORDING | HIT | partner=\(partnerID) key=\(key.debugLabel)")
        return partnerRecording
    }

    if let fallback = recordingStore.find(partnerID: defaultPartnerID, key: key) {
        DebugLog.shared.log("RESOLVE_RECORDING | FALLBACK | requested=\(partnerID) used=\(defaultPartnerID) key=\(key.debugLabel)")
        return fallback
    }

    return onMissingDefault("Missing default recording for \(key.debugLabel)")
}
