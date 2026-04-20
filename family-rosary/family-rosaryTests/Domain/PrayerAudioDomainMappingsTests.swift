import Foundation
import XCTest
@testable import family_rosary

final class PrayerAudioDomainMappingsTests: XCTestCase {
    func testPrayerLineKeySupportsEqualityAndHashing() {
        let left = PrayerLineKey(prayer: .hailMary, role: .lead)
        let right = PrayerLineKey(prayer: .hailMary, role: .lead)
        let different = PrayerLineKey(prayer: .hailMary, role: .respond)

        XCTAssertEqual(left, right)
        XCTAssertNotEqual(left, different)
        XCTAssertEqual(Set([left, right, different]).count, 2)
    }

    func testTrimDefinitionUsesUserOverridesWhenPresent() {
        let trim = TrimDefinition(
            suggestedStart: 0.3,
            suggestedEnd: 9.5,
            userStart: 0.8,
            userEnd: 8.9
        )

        XCTAssertEqual(trim.effectiveStart, 0.8, accuracy: 0.0001)
        XCTAssertEqual(trim.effectiveEnd, 8.9, accuracy: 0.0001)
    }

    func testTrimDefinitionFallsBackToSuggestions() {
        let trim = TrimDefinition(
            suggestedStart: 0.15,
            suggestedEnd: 5.2,
            userStart: nil,
            userEnd: nil
        )

        XCTAssertEqual(trim.effectiveStart, 0.15, accuracy: 0.0001)
        XCTAssertEqual(trim.effectiveEnd, 5.2, accuracy: 0.0001)
    }

    func testPrayerPartnerMapsBuiltInAndPersonalVoiceProfiles() {
        XCTAssertEqual(PrayerPartner(id: "dad", displayName: "Dad").domainVoiceProfile.kind, .builtInCompanion)
        XCTAssertTrue(PrayerPartner(id: "dad", displayName: "Dad").domainVoiceProfile.isBuiltIn)

        let personal = PrayerPartner(id: "grandma", displayName: "Grandma").domainVoiceProfile
        XCTAssertEqual(personal.kind, .personal)
        XCTAssertFalse(personal.isBuiltIn)
        XCTAssertEqual(personal.id.rawValue, "grandma")
        XCTAssertEqual(personal.displayName, "Grandma")
    }

    func testImportSlotMapsToPrayerLineKey() {
        XCTAssertEqual(
            ImportSlot.hailMaryResponse.domainPrayerLineKey,
            PrayerLineKey(prayer: .hailMary, role: .respond)
        )
        XCTAssertEqual(
            ImportSlot.fatima.domainPrayerLineKey,
            PrayerLineKey(prayer: .fatimaPrayer, role: .full)
        )
    }

    func testPrayerClipTrimMapsToDomainTrimDefinition() {
        let clip = PrayerClip(
            id: "dad:apostles_creed_lead",
            fileName: "dad_apostles_creed_lead.m4a",
            prayer: "apostles_creed_lead",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 4.82,
            endSec: 28.18
        )

        let trim = clip.domainTrimDefinition
        XCTAssertEqual(trim.suggestedStart, 4.82, accuracy: 0.0001)
        XCTAssertEqual(trim.suggestedEnd, 28.18, accuracy: 0.0001)
        XCTAssertNil(trim.userStart)
        XCTAssertNil(trim.userEnd)
    }

    func testPrayerClipMapsToBundledRecordingAsset() {
        let clip = PrayerClip(
            id: "dad:glory_be_response",
            fileName: "dad_glory_be_response.m4a",
            prayer: "glory_be_response",
            person: "dad",
            dateRecorded: "2026-03-01",
            startSec: 0.4,
            endSec: 7.2
        )

        let asset = try XCTUnwrap(clip.domainRecordingAsset)
        XCTAssertEqual(asset.id.rawValue, "dad:glory_be_response")
        XCTAssertEqual(asset.prayerLineKey, PrayerLineKey(prayer: .gloryBe, role: .respond))
        XCTAssertEqual(asset.ownerProfileID.rawValue, "dad")
        XCTAssertEqual(asset.source, .bundled)
        XCTAssertEqual(asset.storageKey, "dad_glory_be_response.m4a")
        XCTAssertEqual(asset.status, .ready)
    }

    func testFinalisedImportedRecordingMapsToImportedShareRecordingAsset() {
        let recording = FinalisedImportedRecording(
            id: "rec-1",
            importID: "import-1",
            partnerID: "grandma",
            partnerDisplayName: "Grandma",
            ageAtRecording: 72,
            prayer: .ourFather,
            prayerPart: .ourFatherLead,
            libraryFileURL: URL(fileURLWithPath: "/tmp/grandma_our_father_lead.m4a"),
            originalFilename: "memo.m4a",
            durationSeconds: 6.8,
            importedAtISO8601: "2026-04-19T10:00:00Z",
            finalisedAtISO8601: "2026-04-19T10:05:00Z"
        )

        let asset = recording.domainRecordingAsset
        XCTAssertEqual(asset.prayerLineKey, PrayerLineKey(prayer: .ourFather, role: .lead))
        XCTAssertEqual(asset.ownerProfileID.rawValue, "grandma")
        XCTAssertEqual(asset.source, .importedShare)
        XCTAssertEqual(asset.trim.effectiveStart, 0, accuracy: 0.0001)
        XCTAssertEqual(asset.trim.effectiveEnd, 6.8, accuracy: 0.0001)
        XCTAssertEqual(asset.storageKey, "/tmp/grandma_our_father_lead.m4a")
    }

    func testPlaybackSegmentCanBeDerivedFromRecordingAsset() {
        let asset = RecordingAsset(
            id: RecordingAssetID(rawValue: "asset-1"),
            prayerLineKey: PrayerLineKey(prayer: .hailHolyQueen, role: .lead),
            ownerProfileID: VoiceProfileID(rawValue: "mom"),
            source: .bundled,
            trim: TrimDefinition(
                suggestedStart: 0.2,
                suggestedEnd: 14.5,
                userStart: 0.5,
                userEnd: 13.9
            ),
            status: .ready,
            storageKey: "mom_hail_holy_queen_lead.m4a"
        )

        let segment = PlaybackSegment(asset: asset)
        XCTAssertEqual(segment.prayerLineKey, asset.prayerLineKey)
        XCTAssertEqual(segment.recordingAssetID, asset.id)
        XCTAssertEqual(segment.startTime, 0.5, accuracy: 0.0001)
        XCTAssertEqual(segment.endTime, 13.9, accuracy: 0.0001)
        XCTAssertEqual(segment.storageKey, "mom_hail_holy_queen_lead.m4a")
    }
}
