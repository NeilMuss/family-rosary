import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel
    @ObservedObject var sharedInboxScanCoordinator: SharedInboxScanCoordinator

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 24)

                Text("Family Rosary")
                    .font(.system(size: 42, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Partner")
                        .font(.system(size: 22, weight: .semibold))

                    Picker("Partner", selection: $viewModel.selectedPartnerID) {
                        ForEach(viewModel.availablePartners) { partner in
                            Text(partner.displayName)
                                .tag(partner.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 24, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Style")
                        .font(.system(size: 22, weight: .semibold))

                    Picker("Style", selection: $viewModel.selectedStyle) {
                        ForEach(PrayerStyle.allCases) { style in
                            Text(style.displayName)
                                .tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 24, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Mode")
                        .font(.system(size: 22, weight: .semibold))

                    Picker("Mode", selection: $viewModel.selectedMode) {
                        ForEach(PrayerMode.allCases) { mode in
                            Text(mode.displayName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .font(.system(size: 24, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)

                Button(action: viewModel.onTapPray) {
                    Text("Pray")
                        .font(.system(size: 34, weight: .bold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 78)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)

                #if DEBUG
                VStack(alignment: .leading, spacing: 12) {
                    Text("Debug Tools")
                        .font(.system(size: 20, weight: .semibold))
                    SharedInboxDiagnosticsView(viewModel: sharedInboxScanCoordinator)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                #endif

                Spacer(minLength: 24)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color.white)
    }
}
