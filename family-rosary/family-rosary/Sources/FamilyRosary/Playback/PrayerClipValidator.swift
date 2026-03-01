import Foundation

protocol PrayerClipValidating: Sendable {
    func validate(clips: [PrayerClip], bundle: Bundle) -> [String]
}

struct BundlePrayerClipValidator: PrayerClipValidating {
    func validate(clips: [PrayerClip], bundle: Bundle = .main) -> [String] {
        var errors: [String] = []

        for clip in clips {
            if clip.endSec <= clip.startSec {
                errors.append("Clip \(clip.id) has invalid range \(clip.startSec)-\(clip.endSec)")
                continue
            }

            guard let url = bundle.url(forResource: clip.fileName, withExtension: nil, subdirectory: "SeedAudio")
                ?? bundle.url(forResource: clip.fileName, withExtension: nil, subdirectory: "Resources/SeedAudio")
                ?? bundle.url(forResource: clip.fileName, withExtension: nil) else {
                errors.append("Clip \(clip.id) missing bundle file \(clip.fileName)")
                continue
            }

            let fileSize = ((try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? NSNumber)?.int64Value) ?? 0
            if fileSize <= 0 {
                errors.append("Clip \(clip.id) has empty file \(clip.fileName)")
            }
        }

        return errors
    }
}
