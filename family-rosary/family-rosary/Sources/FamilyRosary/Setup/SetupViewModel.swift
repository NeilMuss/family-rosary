import Foundation
import Combine

struct StartRosaryRequest: Equatable {
    let partnerID: String
    let prayerStyle: PrayerStyle
    let prayerMode: PrayerMode
}

@MainActor
final class SetupViewModel: ObservableObject {
    let availablePartners: [PrayerPartner]

    @Published var selectedPartnerID: String
    @Published var selectedStyle: PrayerStyle
    @Published var selectedMode: PrayerMode
    @Published var isCandleBackgroundEnabled: Bool

    private let preferencesStore: RosaryPreferencesStore
    private var onStartPraying: (StartRosaryRequest) -> Void

    init(
        availablePartners: [PrayerPartner],
        preferencesStore: RosaryPreferencesStore,
        onStartPraying: @escaping (StartRosaryRequest) -> Void
    ) {
        self.availablePartners = availablePartners
        self.preferencesStore = preferencesStore
        self.onStartPraying = onStartPraying

        let fallbackPartnerID = availablePartners.first?.id ?? ""
        if let savedPartnerID = preferencesStore.loadLastPartnerID(),
           availablePartners.contains(where: { $0.id == savedPartnerID }) {
            selectedPartnerID = savedPartnerID
        } else {
            selectedPartnerID = fallbackPartnerID
        }

        selectedStyle = preferencesStore.loadLastPrayerStyle() ?? .alternateIStart
        selectedMode = preferencesStore.loadLastPrayerMode() ?? .interactive
        isCandleBackgroundEnabled = preferencesStore.loadCandleBackgroundEnabled()
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

    func setCandleBackgroundEnabled(_ enabled: Bool) {
        guard isCandleBackgroundEnabled != enabled else { return }
        isCandleBackgroundEnabled = enabled
        preferencesStore.saveCandleBackgroundEnabled(enabled)
    }
}
