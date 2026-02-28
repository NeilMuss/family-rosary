import Foundation

enum ImportSlot: CaseIterable, Identifiable, Hashable {
    case apostlesCreed
    case ourFatherLead
    case ourFatherResponse
    case hailMaryLead
    case hailMaryResponse

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
        }
    }
}
