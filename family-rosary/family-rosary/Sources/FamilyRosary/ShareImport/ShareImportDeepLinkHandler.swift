import Foundation

struct ShareImportDeepLinkHandler {
    let expectedScheme: String
    let expectedRoute: String

    init(configuration: SharedImportConfiguration) {
        self.expectedScheme = configuration.urlScheme.lowercased()
        self.expectedRoute = configuration.deepLinkRoute.lowercased()
    }

    init(expectedScheme: String, expectedRoute: String = "share-import") {
        self.expectedScheme = expectedScheme.lowercased()
        self.expectedRoute = expectedRoute.lowercased()
    }

    func recognizes(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased(), scheme == expectedScheme else {
            return false
        }

        if let host = url.host?.lowercased(), host == expectedRoute {
            return true
        }

        let normalizedPath = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        return normalizedPath == expectedRoute
    }
}
