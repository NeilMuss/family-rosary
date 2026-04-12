import Foundation

enum PrayerName: String, CaseIterable, Identifiable, Codable {
    case apostlesCreed
    case ourFather
    case hailMary
    case gloryBe
    case fatima
    case hailHolyQueen

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apostlesCreed:
            return "Apostles' Creed"
        case .ourFather:
            return "Our Father"
        case .hailMary:
            return "Hail Mary"
        case .gloryBe:
            return "Glory Be"
        case .fatima:
            return "Fatima Prayer"
        case .hailHolyQueen:
            return "Hail Holy Queen"
        }
    }

    var availableParts: [AudioRecordingPart] {
        ImportSlot.allCases
            .filter { $0.prayer == self }
            .map(\.audioPart)
    }

    static var supportedImportPrayers: [PrayerName] {
        var prayers: [PrayerName] = []
        for slot in ImportSlot.allCases {
            if prayers.contains(slot.prayer) == false {
                prayers.append(slot.prayer)
            }
        }
        return prayers
    }
}
