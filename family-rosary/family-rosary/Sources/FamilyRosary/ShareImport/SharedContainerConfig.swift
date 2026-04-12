import Foundation

enum SharedContainerConfig {
    static let appGroupIdentifier = "group.com.neilmussett.familyrosary"

    static func resolvedAppGroupIdentifier(bundle: Bundle = .main) -> String {
        let configuredValue = (bundle.object(forInfoDictionaryKey: "FRAppGroupIdentifier") as? String ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if configuredValue.isEmpty {
            return appGroupIdentifier
        }

        return configuredValue
    }
}
