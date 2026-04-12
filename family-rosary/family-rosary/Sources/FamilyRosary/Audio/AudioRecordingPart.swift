import Foundation

enum AudioRecordingPart: String, Codable {
    case apostlesCreed
    case ourFatherLead
    case ourFatherResponse
    case hailMaryLead
    case hailMaryResponse

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
        }
    }
}
