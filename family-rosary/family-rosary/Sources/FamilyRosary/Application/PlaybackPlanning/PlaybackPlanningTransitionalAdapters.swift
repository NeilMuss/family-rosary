import Foundation

/// Transitional adapter that maps the existing rosary sequence model into the new domain
/// `PrayerLineKey` used by `BuildPlaybackPlanUseCase`.
extension PrayerType {
    var domainPrayerLineKey: PrayerLineKey {
        switch self {
        case .apostlesCreedLead:
            return PrayerLineKey(prayer: .apostlesCreed, role: .lead)
        case .apostlesCreedResponse:
            return PrayerLineKey(prayer: .apostlesCreed, role: .respond)
        case .ourFatherLead:
            return PrayerLineKey(prayer: .ourFather, role: .lead)
        case .ourFatherResponse:
            return PrayerLineKey(prayer: .ourFather, role: .respond)
        case .hailMaryLead:
            return PrayerLineKey(prayer: .hailMary, role: .lead)
        case .hailMaryResponse:
            return PrayerLineKey(prayer: .hailMary, role: .respond)
        case .gloryBeLead:
            return PrayerLineKey(prayer: .gloryBe, role: .lead)
        case .gloryBeResponse:
            return PrayerLineKey(prayer: .gloryBe, role: .respond)
        case .fatima:
            return PrayerLineKey(prayer: .fatimaPrayer, role: .full)
        case .hailHolyQueenOpeningLead:
            return PrayerLineKey(prayer: .hailHolyQueenOpening, role: .lead)
        case .hailHolyQueenResponse:
            return PrayerLineKey(prayer: .hailHolyQueenResponse, role: .respond)
        case .hailHolyQueenClosingLead:
            return PrayerLineKey(prayer: .hailHolyQueenClosing, role: .lead)
        }
    }
}

/// Transitional compatibility adapter so planner tests can compare the new domain keys
/// with the existing playback resolver behavior without changing production code paths.
extension PrayerLineKey {
    var legacyRecordingKey: RecordingKey {
        RecordingKey(
            prayer: prayer.legacyPrayerName,
            part: role.legacyPrayerPart
        )
    }
}

private extension PrayerKey {
    var legacyPrayerName: PrayerName {
        switch self {
        case .apostlesCreed:
            return .apostlesCreed
        case .ourFather:
            return .ourFather
        case .hailMary:
            return .hailMary
        case .gloryBe:
            return .gloryBe
        case .fatimaPrayer:
            return .fatima
        case .hailHolyQueenOpening, .hailHolyQueenResponse, .hailHolyQueenClosing:
            return .hailHolyQueen
        case .hailHolyQueen:
            return .hailHolyQueen
        }
    }
}

private extension PrayerRole {
    var legacyPrayerPart: PrayerPart {
        switch self {
        case .lead:
            return .lead
        case .respond:
            return .response
        case .full:
            return .full
        }
    }
}
