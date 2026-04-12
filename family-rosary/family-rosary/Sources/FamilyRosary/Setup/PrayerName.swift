import Foundation

enum PrayerName: String, CaseIterable, Identifiable, Codable {
    case apostlesCreed
    case ourFather
    case hailMary

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apostlesCreed:
            return "Apostles' Creed"
        case .ourFather:
            return "Our Father"
        case .hailMary:
            return "Hail Mary"
        }
    }

    var availableParts: [AudioRecordingPart] {
        switch self {
        case .apostlesCreed:
            return [.apostlesCreed]
        case .ourFather:
            return [.ourFatherLead, .ourFatherResponse]
        case .hailMary:
            return [.hailMaryLead, .hailMaryResponse]
        }
    }
}
