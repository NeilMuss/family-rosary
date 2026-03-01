import Foundation

actor AudioTrimCache {
    private var storage: [URL: TrimRange?] = [:]

    func get(_ url: URL) -> TrimRange?? {
        storage[url]
    }

    func set(_ value: TrimRange?, for url: URL) {
        storage[url] = value
    }
}
