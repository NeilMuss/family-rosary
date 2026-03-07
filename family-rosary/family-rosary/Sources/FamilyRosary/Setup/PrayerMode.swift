import Foundation

enum PrayerMode: String, CaseIterable, Identifiable {
    case interactive
    case automatic

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .interactive:
            return "Interactive"
        case .automatic:
            return "Automatic"
        }
    }
}
