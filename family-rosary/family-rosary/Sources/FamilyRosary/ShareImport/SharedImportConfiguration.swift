import Foundation

struct SharedImportConfiguration: Equatable {
    let appGroupIdentifier: String
    let urlScheme: String
    let deepLinkRoute: String

    static func fromMainBundle(bundle: Bundle = .main) -> SharedImportConfiguration {
        let appGroupIdentifier = SharedContainerConfig.resolvedAppGroupIdentifier(bundle: bundle)
        let urlScheme = (bundle.object(forInfoDictionaryKey: "FRShareImportURLScheme") as? String ?? "familyrosary").trimmingCharacters(in: .whitespacesAndNewlines)
        return SharedImportConfiguration(
            appGroupIdentifier: appGroupIdentifier,
            urlScheme: urlScheme,
            deepLinkRoute: "share-import"
        )
    }

    func makeShareImportURL(importID: String? = nil) -> URL? {
        var components = URLComponents()
        components.scheme = urlScheme
        components.host = deepLinkRoute
        if let importID, !importID.isEmpty {
            components.queryItems = [
                URLQueryItem(name: "import_id", value: importID)
            ]
        }
        return components.url
    }
}
