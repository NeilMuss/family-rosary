import Foundation

enum AudioRecordingPart: String, Codable {
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

    nonisolated var filenameToken: String {
        switch self {
        case .apostlesCreed:
            return "apostles_creed"
        case .ourFatherLead:
            return "our_father_lead"
        case .ourFatherResponse:
            return "our_father_response"
        case .hailMaryLead:
            return "hail_lead"
        case .hailMaryResponse:
            return "hail_response"
        case .gloryBeLead:
            return "glory_be_lead"
        case .gloryBeResponse:
            return "glory_be_response"
        case .fatima:
            return "fatima"
        case .hailHolyQueenLead:
            return "hail_holy_queen_lead"
        case .hailHolyQueenResponse:
            return "hail_holy_queen_response"
        case .hailHolyQueenClosing:
            return "hail_holy_queen_closing"
        }
    }

    nonisolated var displayTitle: String {
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
}
