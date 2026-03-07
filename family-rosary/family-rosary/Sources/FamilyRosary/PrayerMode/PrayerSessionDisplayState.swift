import Foundation

struct PrayerSessionDisplayState: Equatable {
    let sectionTitle: String
    let prayerTitle: String
    let countText: String?
    let rolePrompt: String?
    let isPaused: Bool
}
