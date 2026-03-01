import Foundation
#if canImport(MachO)
import MachO
#endif

enum PreviewRuntime {
    static var isRunningForPreviews: Bool {
        isRunningForPreviews(
            environment: ProcessInfo.processInfo.environment,
            imageNames: loadedImageNames()
        )
    }

    static func isRunningForPreviews(
        environment: [String: String],
        imageNames: [String]
    ) -> Bool {
        if environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            return true
        }
        return isInjectedByPreviewsExecutor(imageNames: imageNames)
    }

    static func isRunningForPreviews(environment: [String: String]) -> Bool {
        isRunningForPreviews(environment: environment, imageNames: loadedImageNames())
    }

    static func isInjectedByPreviewsExecutor(imageNames: [String]) -> Bool {
        imageNames.contains { imageName in
            imageName.localizedCaseInsensitiveContains("Previews")
                || imageName.localizedCaseInsensitiveContains("Preview")
                || imageName.localizedCaseInsensitiveContains("Injection")
        }
    }

    private static func loadedImageNames() -> [String] {
        #if canImport(MachO)
        let imageCount = _dyld_image_count()
        var names: [String] = []
        names.reserveCapacity(Int(imageCount))
        for index in 0..<imageCount {
            guard let cName = _dyld_get_image_name(index) else { continue }
            names.append(String(cString: cName))
        }
        return names
        #else
        return []
        #endif
    }
}
