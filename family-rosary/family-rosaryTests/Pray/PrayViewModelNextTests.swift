import Foundation
import XCTest
@testable import family_rosary

@MainActor
final class PrayViewModelNextTests: XCTestCase {
    func testOnTapPrayStartingAtPrayerIndexBuildsSuffixOfSequence() async {
        let fakeSequencePlayer = PrayNextFakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = PrayNextFakeAudioFileResolver()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: PrayNextAlwaysGrantedMicrophonePermissionClient()
        )

        viewModel.onTapPray(startingAtPrayerIndex: 1)
        await Task.yield()

        XCTAssertEqual(fakeSequencePlayer.receivedSteps.count, 278)
        XCTAssertEqual(
            fakeSequencePlayer.receivedSteps[0],
            .play(
                asset: AudioAssetRef(
                    id: "dad:apostles_creed_response",
                    url: URL(fileURLWithPath: "/tmp/dad_apostles_creed_response.m4a")
                ),
                prompt: PrayerPrompt(title: "Listen", text: "I believe in God, the Father almighty...")
            )
        )

        fakeSequencePlayer.releasePlay()
    }

    func testOnTapPrayStartingAtFatimaBuildsFatimaPlaybackStep() async {
        let fakeSequencePlayer = PrayNextFakePrayerSequencePlayer(blockUntilReleased: true)
        let resolver = PrayNextFakeAudioFileResolver()
        seedResolver(resolver)

        let viewModel = PrayViewModel(
            personID: "dad",
            sequencePlayer: fakeSequencePlayer,
            resolver: resolver,
            microphonePermissionClient: PrayNextAlwaysGrantedMicrophonePermissionClient()
        )
        viewModel.isInteractive = true
        viewModel.interactiveStyle = .alternateIStart

        let fatimaIndex = RosarySequenceBuilder.makeStandardRosary().firstIndex(of: .fatima)
        XCTAssertNotNil(fatimaIndex)

        guard let fatimaIndex else { return }

        viewModel.onTapPray(startingAtPrayerIndex: fatimaIndex)
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(
            fakeSequencePlayer.receivedSteps.first,
            .play(
                asset: AudioAssetRef(
                    id: "dad:fatima",
                    url: URL(fileURLWithPath: "/tmp/dad_fatima.m4a")
                ),
                prompt: PrayerPrompt(title: "Pray together", text: "O my Jesus, forgive us our sins...")
            )
        )

        fakeSequencePlayer.releasePlay()
    }

    private func seedResolver(_ resolver: PrayNextFakeAudioFileResolver) {
        resolver.stub(personID: "dad", token: "apostles_creed_lead", path: "/tmp/dad_apostles_creed_lead.m4a")
        resolver.stub(personID: "dad", token: "apostles_creed_response", path: "/tmp/dad_apostles_creed_response.m4a")
        resolver.stub(personID: "dad", token: "our_father_lead", path: "/tmp/dad_our_father_lead.m4a")
        resolver.stub(personID: "dad", token: "our_father_response", path: "/tmp/dad_our_father_response.m4a")
        resolver.stub(personID: "dad", token: "hail_lead", path: "/tmp/dad_hail_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_response", path: "/tmp/dad_hail_response.m4a")
        resolver.stub(personID: "dad", token: "glory_be_lead", path: "/tmp/dad_glory_be_lead.m4a")
        resolver.stub(personID: "dad", token: "glory_be_response", path: "/tmp/dad_glory_be_response.m4a")
        resolver.stub(personID: "dad", token: "fatima", path: "/tmp/dad_fatima.m4a")
        resolver.stub(personID: "dad", token: "hail_holy_queen_lead", path: "/tmp/dad_hail_holy_queen_lead.m4a")
        resolver.stub(personID: "dad", token: "hail_holy_queen_response", path: "/tmp/dad_hail_holy_queen_response.m4a")
        resolver.stub(personID: "dad", token: "hail_holy_queen_closing", path: "/tmp/dad_hail_holy_queen_closing.m4a")
    }
}

private final class PrayNextFakeAudioFileResolver: AudioFileResolving {
    private var urls: [String: URL] = [:]

    func stub(personID: String, token: String, path: String) {
        urls["\(personID)|\(token)"] = URL(fileURLWithPath: path)
    }

    func resolve(personID: String, token: String) -> URL? {
        urls["\(personID)|\(token)"]
    }
}

private final class PrayNextFakePrayerSequencePlayer: PrayerSequencePlaying {
    private let blockUntilReleased: Bool
    private var continuation: CheckedContinuation<Void, Never>?

    private(set) var receivedSteps: [PrayerSequenceStep] = []

    init(blockUntilReleased: Bool = false) {
        self.blockUntilReleased = blockUntilReleased
    }

    func play(
        steps: [PrayerSequenceStep],
        onPromptChanged: @escaping (PrayerPrompt?) -> Void,
        onDebugStatusChanged: ((PrayDebugStatus) -> Void)?
    ) async throws {
        _ = onPromptChanged
        _ = onDebugStatusChanged
        receivedSteps = steps

        if blockUntilReleased {
            await withCheckedContinuation { continuation in
                self.continuation = continuation
            }
        }
    }

    func stop() {
        releasePlay()
    }

    func releasePlay() {
        continuation?.resume()
        continuation = nil
    }
}

private struct PrayNextAlwaysGrantedMicrophonePermissionClient: MicrophonePermissionClient {
    func requestAccess() async -> Bool { true }
}
