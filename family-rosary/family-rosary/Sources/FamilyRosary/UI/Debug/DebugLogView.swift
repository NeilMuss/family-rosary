import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DebugLogView: View {
    @ObservedObject var log = DebugLog.shared

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Button("Copy") {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = log.copyAll()
                    #endif
                }

                Button("Clear") {
                    log.clear()
                }

                Spacer()

                Text("Debug Log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(log.entries.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(6)
        .background(Color.black.opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
