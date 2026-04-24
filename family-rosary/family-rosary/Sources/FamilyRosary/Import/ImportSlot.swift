import Foundation

enum ImportSlot: CaseIterable, Identifiable, Hashable {
    case apostlesCreed
    case ourFatherLead
    case ourFatherResponse
    case hailMaryLead
    case hailMaryResponse
    case gloryBeLead
    case gloryBeResponse
    case fatima
    case hailHolyQueenLead
    case hailHolyQueenResponse
    case hailHolyQueenClosing

    nonisolated var id: String {
        audioPart.filenameToken
    }

    nonisolated var displayName: String {
        switch self {
        case .apostlesCreed:
            return "Apostles' Creed"
        case .ourFatherLead:
            return "Our Father (Lead)"
        case .ourFatherResponse:
            return "Our Father (Response)"
        case .hailMaryLead:
            return "Hail Mary (Lead)"
        case .hailMaryResponse:
            return "Hail Mary (Response)"
        case .gloryBeLead:
            return "Glory Be (Lead)"
        case .gloryBeResponse:
            return "Glory Be (Response)"
        case .fatima:
            return "Fatima Prayer"
        case .hailHolyQueenLead:
            return "Hail Holy Queen (Lead)"
        case .hailHolyQueenResponse:
            return "Hail Holy Queen (Response)"
        case .hailHolyQueenClosing:
            return "Hail Holy Queen (Closing Lead)"
        }
    }

    nonisolated var audioPart: AudioRecordingPart {
        switch self {
        case .apostlesCreed:
            return .apostlesCreed
        case .ourFatherLead:
            return .ourFatherLead
        case .ourFatherResponse:
            return .ourFatherResponse
        case .hailMaryLead:
            return .hailMaryLead
        case .hailMaryResponse:
            return .hailMaryResponse
        case .gloryBeLead:
            return .gloryBeLead
        case .gloryBeResponse:
            return .gloryBeResponse
        case .fatima:
            return .fatima
        case .hailHolyQueenLead:
            return .hailHolyQueenLead
        case .hailHolyQueenResponse:
            return .hailHolyQueenResponse
        case .hailHolyQueenClosing:
            return .hailHolyQueenClosing
        }
    }

    nonisolated var prayer: PrayerName {
        switch self {
        case .apostlesCreed:
            return .apostlesCreed
        case .ourFatherLead, .ourFatherResponse:
            return .ourFather
        case .hailMaryLead, .hailMaryResponse:
            return .hailMary
        case .gloryBeLead, .gloryBeResponse:
            return .gloryBe
        case .fatima:
            return .fatima
        case .hailHolyQueenLead, .hailHolyQueenResponse, .hailHolyQueenClosing:
            return .hailHolyQueen
        }
    }
}
