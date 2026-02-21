import Foundation

enum AudioRecordingPart {
    case hailMaryLead
    case hailMaryResponse

    var filenameToken: String {
        switch self {
        case .hailMaryLead:
            return "hail_lead"
        case .hailMaryResponse:
            return "hail_response"
        }
    }

    var displayTitle: String {
        switch self {
        case .hailMaryLead:
            return "Hail Mary (Lead)"
        case .hailMaryResponse:
            return "Hail Mary (Response)"
        }
    }
}
