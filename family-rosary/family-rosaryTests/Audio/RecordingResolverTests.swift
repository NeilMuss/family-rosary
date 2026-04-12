import Foundation
import XCTest
@testable import family_rosary

final class RecordingResolverTests: XCTestCase {
    func test_resolve_returns_partner_recording_when_available() {
        let key = RecordingKey(prayer: .hailMary, part: .lead)
        let partnerRecording = Recording(
            partnerID: "alice",
            key: key,
            fileURL: URL(fileURLWithPath: "/tmp/alice_hail_lead.m4a")
        )
        let store = InMemoryRecordingStore(recordings: [
            "alice|\(key.debugLabel)": partnerRecording
        ])

        let resolved = resolveRecording(
            partnerID: "alice",
            key: key,
            recordingStore: store,
            defaultPartnerID: PlaybackPartnerDefaults.defaultPartnerID
        )

        XCTAssertEqual(resolved, partnerRecording)
    }

    func test_resolve_falls_back_to_default_when_missing() {
        let key = RecordingKey(prayer: .hailMary, part: .response)
        let fallbackRecording = Recording(
            partnerID: PlaybackPartnerDefaults.defaultPartnerID,
            key: key,
            fileURL: URL(fileURLWithPath: "/tmp/dad_hail_response.m4a")
        )
        let store = InMemoryRecordingStore(recordings: [
            "\(PlaybackPartnerDefaults.defaultPartnerID)|\(key.debugLabel)": fallbackRecording
        ])

        let resolved = resolveRecording(
            partnerID: "alice",
            key: key,
            recordingStore: store,
            defaultPartnerID: PlaybackPartnerDefaults.defaultPartnerID
        )

        XCTAssertEqual(resolved, fallbackRecording)
    }

    #if DEBUG
    func test_resolve_crashes_if_default_missing() {
        let key = RecordingKey(prayer: .gloryBe, part: .lead)
        let store = InMemoryRecordingStore(recordings: [:])
        let sentinel = Recording(
            partnerID: "sentinel",
            key: key,
            fileURL: URL(fileURLWithPath: "/tmp/sentinel.m4a")
        )
        var receivedMessage: String?

        let resolved = resolveRecording(
            partnerID: "alice",
            key: key,
            recordingStore: store,
            defaultPartnerID: PlaybackPartnerDefaults.defaultPartnerID,
            onMissingDefault: { message in
                receivedMessage = message
                return sentinel
            }
        )

        XCTAssertEqual(receivedMessage, "Missing default recording for gloryBe.lead")
        XCTAssertEqual(resolved, sentinel)
    }
    #endif
}

private struct InMemoryRecordingStore: RecordingStore {
    let recordings: [String: Recording]

    func find(partnerID: String, key: RecordingKey) -> Recording? {
        recordings["\(partnerID)|\(key.debugLabel)"]
    }
}
