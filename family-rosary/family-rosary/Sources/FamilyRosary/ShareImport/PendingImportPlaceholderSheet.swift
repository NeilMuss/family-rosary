import SwiftUI

struct PendingImportPlaceholderSheet: View {
    let pendingImport: PendingImport
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Finish Import Coming Next")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("The recording has been imported into the library and saved as a pending import, but it has not been finalised yet.")
                    .foregroundStyle(.secondary)

                Text("Filename: \(pendingImport.originalFilename)")
                Text("Import ID: \(pendingImport.importID)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Pending Import")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        onClose()
                    }
                }
            }
        }
    }
}
