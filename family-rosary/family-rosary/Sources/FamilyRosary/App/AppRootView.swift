import SwiftUI

struct AppRootView: View {
    let root: AppCompositionRoot

    var body: some View {
        root.makeRecordPrayerView(
            personID: "dad",
            part: .hailMaryLead,
            promptText: "Say a Hail Mary for Mom.",
            onDone: {}
        )
    }
}

#Preview {
    AppRootView(root: AppCompositionRoot())
}
