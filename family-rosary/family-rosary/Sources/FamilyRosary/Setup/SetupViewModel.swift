import Foundation
import Combine

struct StartRosaryRequest: Equatable {
    let partnerID: String
    let prayerStyle: PrayerStyle
}

@MainActor
final class SetupViewModel: ObservableObject {
    let availablePartners: [PrayerPartner]

    @Published var selectedPartnerID: String
    @Published var selectedStyle: PrayerStyle

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
    }

    func onTapPray() {
        guard !selectedPartnerID.isEmpty else { return }

        preferencesStore.saveLastPartnerID(selectedPartnerID)
        preferencesStore.saveLastPrayerStyle(selectedStyle)

        onStartPraying(
            StartRosaryRequest(
                partnerID: selectedPartnerID,
                prayerStyle: selectedStyle
            )
        )
    }

    func setOnStartPraying(_ onStartPraying: @escaping (StartRosaryRequest) -> Void) {
        self.onStartPraying = onStartPraying
    }
}
