import Foundation

enum PrayerStyle: String, CaseIterable, Identifiable {
    case alternateIStart
    case alternateIRespond
    case alwaysLead
    case alwaysRespond

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .alternateIStart:
            return "Alternate — I start"
        case .alternateIRespond:
            return "Alternate — I respond"
        case .alwaysLead:
            return "I always lead"
        case .alwaysRespond:
            return "I always respond"
        }
    }
}
