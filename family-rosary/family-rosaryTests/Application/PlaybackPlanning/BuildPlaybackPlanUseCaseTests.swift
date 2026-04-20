import Foundation
import XCTest
@testable import family_rosary

final class BuildPlaybackPlanUseCaseTests: XCTestCase {
    func test_prefersPersonalAssetWhenReadyAssetExists() throws {
        let key = PrayerLineKey(prayer: .hailMary, role: .lead)
        let personal = makeAsset(id: "personal", owner: "alice", key: key, source: .importedFile)
        let fallback = makeAsset(id: "fallback", owner: "dad", key: key, source: .bundled)
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [personal, fallback])
        )

        let plan = try useCase.execute(
            prayerSequence: [key],
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        XCTAssertEqual(plan.segments.map(\.recordingAssetID.rawValue), ["personal"])
    }

    func test_fallsBackToBuiltInCompanionWhenPersonalAssetMissing() throws {
        let key = PrayerLineKey(prayer: .hailMary, role: .respond)
        let fallback = makeAsset(id: "fallback", owner: "dad", key: key, source: .bundled)
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [fallback])
        )

        let plan = try useCase.execute(
            prayerSequence: [key],
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        XCTAssertEqual(plan.segments.map(\.recordingAssetID.rawValue), ["fallback"])
    }

    func test_usesTrimDefinitionEffectiveStartAndEnd() throws {
        let key = PrayerLineKey(prayer: .gloryBe, role: .lead)
        let asset = makeAsset(
            id: "trimmed",
            owner: "alice",
            key: key,
            source: .importedShare,
            trim: TrimDefinition(suggestedStart: 0.3, suggestedEnd: 8.4, userStart: 0.8, userEnd: 7.6)
        )
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [asset])
        )

        let plan = try useCase.execute(
            prayerSequence: [key],
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        XCTAssertEqual(plan.segments[0].startTime, 0.8, accuracy: 0.0001)
        XCTAssertEqual(plan.segments[0].endTime, 7.6, accuracy: 0.0001)
    }

    func test_ignoresNonReadyAssetsWhenResolvingPlan() throws {
        let key = PrayerLineKey(prayer: .ourFather, role: .lead)
        let stagedPersonal = makeAsset(id: "staged", owner: "alice", key: key, source: .importedFile, status: .staged)
        let readyFallback = makeAsset(id: "ready", owner: "dad", key: key, source: .bundled)
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [stagedPersonal, readyFallback])
        )

        let plan = try useCase.execute(
            prayerSequence: [key],
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        XCTAssertEqual(plan.segments.map(\.recordingAssetID.rawValue), ["ready"])
    }

    func test_preservesInputPrayerSequenceOrder() throws {
        let first = PrayerLineKey(prayer: .ourFather, role: .lead)
        let second = PrayerLineKey(prayer: .ourFather, role: .respond)
        let third = PrayerLineKey(prayer: .fatimaPrayer, role: .full)
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [
                makeAsset(id: "one", owner: "dad", key: first, source: .bundled),
                makeAsset(id: "two", owner: "dad", key: second, source: .bundled),
                makeAsset(id: "three", owner: "dad", key: third, source: .bundled)
            ])
        )

        let plan = try useCase.execute(
            prayerSequence: [first, second, third],
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        XCTAssertEqual(plan.segments.map(\.recordingAssetID.rawValue), ["one", "two", "three"])
    }

    func test_handlesMixedAvailabilityAcrossMultiplePrayerLines() throws {
        let lead = PrayerLineKey(prayer: .hailMary, role: .lead)
        let respond = PrayerLineKey(prayer: .hailMary, role: .respond)
        let glory = PrayerLineKey(prayer: .gloryBe, role: .respond)
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [
                makeAsset(id: "alice-lead", owner: "alice", key: lead, source: .importedFile),
                makeAsset(id: "dad-respond", owner: "dad", key: respond, source: .bundled),
                makeAsset(id: "alice-glory", owner: "alice", key: glory, source: .importedShare)
            ])
        )

        let plan = try useCase.execute(
            prayerSequence: [lead, respond, glory],
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        XCTAssertEqual(plan.segments.map(\.recordingAssetID.rawValue), ["alice-lead", "dad-respond", "alice-glory"])
    }

    func test_plannerMatchesExistingResolverFallbackRuleForRepresentativeSequence() throws {
        let sequence = [
            PrayerType.hailMaryLead.domainPrayerLineKey,
            PrayerType.hailMaryResponse.domainPrayerLineKey,
            PrayerType.gloryBeLead.domainPrayerLineKey
        ]
        let readyPersonalLead = makeAsset(id: "alice-lead", owner: "alice", key: sequence[0], source: .importedFile)
        let readyFallbackRespond = makeAsset(id: "dad-respond", owner: "dad", key: sequence[1], source: .bundled)
        let readyFallbackGlory = makeAsset(id: "dad-glory", owner: "dad", key: sequence[2], source: .bundled)
        let useCase = BuildPlaybackPlanUseCase(
            lookup: InMemoryRecordingAssetLookup(assets: [readyPersonalLead, readyFallbackRespond, readyFallbackGlory])
        )

        let plan = try useCase.execute(
            prayerSequence: sequence,
            preferredProfileID: VoiceProfileID(rawValue: "alice"),
            fallbackProfileID: VoiceProfileID(rawValue: "dad")
        )

        let recordingStore = InMemoryRecordingStore(recordings: [
            "alice|\(sequence[0].legacyRecordingKey.debugLabel)": Recording(
                partnerID: "alice",
                key: sequence[0].legacyRecordingKey,
                fileURL: URL(fileURLWithPath: "/tmp/alice-lead.m4a")
            ),
            "dad|\(sequence[1].legacyRecordingKey.debugLabel)": Recording(
                partnerID: "dad",
                key: sequence[1].legacyRecordingKey,
                fileURL: URL(fileURLWithPath: "/tmp/dad-respond.m4a")
            ),
            "dad|\(sequence[2].legacyRecordingKey.debugLabel)": Recording(
                partnerID: "dad",
                key: sequence[2].legacyRecordingKey,
                fileURL: URL(fileURLWithPath: "/tmp/dad-glory.m4a")
            )
        ])

        let legacyResolvedPartners = sequence.map {
            resolveRecording(
                partnerID: "alice",
                key: $0.legacyRecordingKey,
                recordingStore: recordingStore,
                defaultPartnerID: "dad"
            ).partnerID
        }

        XCTAssertEqual(plan.segments.map(\.recordingAssetID.rawValue), ["alice-lead", "dad-respond", "dad-glory"])
        XCTAssertEqual(legacyResolvedPartners, ["alice", "dad", "dad"])
    }

    private func makeAsset(
        id: String,
        owner: String,
        key: PrayerLineKey,
        source: RecordingSource,
        trim: TrimDefinition = TrimDefinition(suggestedStart: 0.1, suggestedEnd: 5.5, userStart: nil, userEnd: nil),
        status: RecordingStatus = .ready
    ) -> RecordingAsset {
        RecordingAsset(
            id: RecordingAssetID(rawValue: id),
            prayerLineKey: key,
            ownerProfileID: VoiceProfileID(rawValue: owner),
            source: source,
            trim: trim,
            status: status,
            storageKey: "\(owner)-\(id).m4a"
        )
    }
}

private struct InMemoryRecordingAssetLookup: RecordingAssetLookup {
    let assets: [RecordingAsset]

    func findAsset(ownerProfileID: VoiceProfileID, prayerLineKey: PrayerLineKey) -> RecordingAsset? {
        assets.first {
            $0.ownerProfileID == ownerProfileID && $0.prayerLineKey == prayerLineKey
        }
    }
}

private struct InMemoryRecordingStore: RecordingStore {
    let recordings: [String: Recording]

    func find(partnerID: String, key: RecordingKey) -> Recording? {
        recordings["\(partnerID)|\(key.debugLabel)"]
    }
}
