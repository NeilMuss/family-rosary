import Foundation

struct PrayerClip: Equatable, Sendable {
    let id: String
    let fileName: String
    let prayer: String
    let person: String
    let dateRecorded: String
    let startSec: Double
    let endSec: Double
}

protocol PrayerClipCatalog: Sendable {
    func allClips() -> [PrayerClip]
    func clip(id: String) -> PrayerClip?
}

struct StaticPrayerClipCatalog: PrayerClipCatalog {
    private let clips: [PrayerClip] = [
        PrayerClip(
            id: "dad:apostles_creed_lead",
            fileName: "dad_apostles_creed_lead.m4a",
            prayer: "apostles_creed",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 4.82,
            endSec: 28.18
        ),
        PrayerClip(
            id: "dad:apostles_creed_response",
            fileName: "dad_apostles_creed_response.m4a",
            prayer: "apostles_creed",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.0,
            endSec: 10_000.0
        ),
        PrayerClip(
            id: "dad:our_father_lead",
            fileName: "dad_our_father_lead.m4a",
            prayer: "our_father",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.0,
            endSec: 10_000.0
        ),
        PrayerClip(
            id: "dad:our_father_response",
            fileName: "dad_our_father_response.m4a",
            prayer: "our_father",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.0,
            endSec: 10_000.0
        ),
        PrayerClip(
            id: "dad:hail_lead",
            fileName: "dad_hail_lead.m4a",
            prayer: "hail_mary",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.0,
            endSec: 10_000.0
        ),
        PrayerClip(
            id: "dad:hail_response",
            fileName: "dad_hail_response.m4a",
            prayer: "hail_mary",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.0,
            endSec: 10_000.0
        )
    ]

    func allClips() -> [PrayerClip] {
        clips
    }

    func clip(id: String) -> PrayerClip? {
        clips.first { $0.id == id }
    }
}
