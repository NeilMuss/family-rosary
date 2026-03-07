import SwiftUI

struct SetupView: View {
    @ObservedObject var viewModel: SetupViewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

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

            Button(action: viewModel.onTapPray) {
                Text("Pray")
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 78)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.white)
    }
}
