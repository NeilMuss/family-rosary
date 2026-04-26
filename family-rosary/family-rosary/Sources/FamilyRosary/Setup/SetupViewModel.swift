import Foundation
import Combine

struct StartRosaryRequest: Equatable {
    let partnerID: String
    let prayerStyle: PrayerStyle
    let prayerMode: PrayerMode
}

@MainActor
final class SetupViewModel: ObservableObject {
    private static let builtInVoiceIDs: Set<String> = ["dad", "mom"]

    let availablePartners: [PrayerPartner]

    @Published var selectedPartnerID: String
    @Published var selectedStyle: PrayerStyle
    @Published var selectedMode: PrayerMode
    @Published var isCandleBackgroundEnabled: Bool
    @Published private(set) var sharedVoiceRecordings: [FinalisedImportedRecording] = []

    private let preferencesStore: RosaryPreferencesStore
    private let finalisedRecordingStore: FinalisedImportedRecordingStoring
    private var onStartPraying: (StartRosaryRequest) -> Void
    private var onShowOnboarding: () -> Void

    // Default Voice is always available; Shared Voices are optional user-added recordings.
    var sharedVoices: [PrayerPartner] {
        availablePartners.filter { Self.builtInVoiceIDs.contains($0.id) == false }
    }

    var sharedVoicesSummary: String {
        let names = sharedVoices.map(\.displayName)
        if names.isEmpty == false {
            return names.joined(separator: ", ")
        }
        return sharedVoiceRecordings.isEmpty ? "No voices yet" : "\(sharedVoiceRecordings.count) recordings"
    }

    init(
        availablePartners: [PrayerPartner],
        preferencesStore: RosaryPreferencesStore,
        finalisedRecordingStore: FinalisedImportedRecordingStoring? = nil,
        onStartPraying: @escaping (StartRosaryRequest) -> Void,
        onShowOnboarding: @escaping () -> Void = {}
    ) {
        self.availablePartners = availablePartners
        self.preferencesStore = preferencesStore
        self.finalisedRecordingStore = finalisedRecordingStore ?? EmptyFinalisedImportedRecordingStore()
        self.onStartPraying = onStartPraying
        self.onShowOnboarding = onShowOnboarding

        let fallbackPartnerID = availablePartners.first?.id ?? ""
        if let savedPartnerID = preferencesStore.loadLastPartnerID(),
           availablePartners.contains(where: { $0.id == savedPartnerID }) {
            selectedPartnerID = savedPartnerID
        } else {
            selectedPartnerID = fallbackPartnerID
        }

        // Default mode set to 'user responds' to reduce ambiguity for first-time users.
        selectedStyle = preferencesStore.loadLastPrayerStyle() ?? .alwaysRespond
        selectedMode = preferencesStore.loadLastPrayerMode() ?? .interactive
        isCandleBackgroundEnabled = preferencesStore.loadCandleBackgroundEnabled()
        reloadSharedVoiceRecordings()
    }

    func onTapPray() {
        guard !selectedPartnerID.isEmpty else { return }

        preferencesStore.saveLastPartnerID(selectedPartnerID)
        preferencesStore.saveLastPrayerStyle(selectedStyle)
        preferencesStore.saveLastPrayerMode(selectedMode)
        preferencesStore.saveCandleBackgroundEnabled(isCandleBackgroundEnabled)

        onStartPraying(
            StartRosaryRequest(
                partnerID: selectedPartnerID,
                prayerStyle: selectedStyle,
                prayerMode: selectedMode
            )
        )
    }

    func setOnStartPraying(_ onStartPraying: @escaping (StartRosaryRequest) -> Void) {
        self.onStartPraying = onStartPraying
    }

    func setOnShowOnboarding(_ onShowOnboarding: @escaping () -> Void) {
        self.onShowOnboarding = onShowOnboarding
    }

    func showOnboarding() {
        onShowOnboarding()
    }

    func reloadSharedVoiceRecordings() {
        sharedVoiceRecordings = ((try? finalisedRecordingStore.all()) ?? [])
            .sorted { lhs, rhs in
                if lhs.partnerDisplayName != rhs.partnerDisplayName {
                    return (lhs.partnerDisplayName ?? lhs.partnerID) < (rhs.partnerDisplayName ?? rhs.partnerID)
                }
                return lhs.prayerPart.displayTitle < rhs.prayerPart.displayTitle
            }
    }

    func deleteRecording(_ recording: FinalisedImportedRecording) {
        try? finalisedRecordingStore.delete(
            partnerID: recording.partnerID,
            prayerLineKey: recording.prayerPart.domainPrayerLineKey
        )
        reloadSharedVoiceRecordings()
    }

    func setCandleBackgroundEnabled(_ enabled: Bool) {
        guard isCandleBackgroundEnabled != enabled else { return }
        isCandleBackgroundEnabled = enabled
        preferencesStore.saveCandleBackgroundEnabled(enabled)
    }
}
