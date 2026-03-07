import Foundation
import Combine

final class DebugLog: ObservableObject {
    static let shared = DebugLog()

    @Published private(set) var entries: [String] = []

    private init() {}

    func log(_ message: String) {
        #if DEBUG
        let timestamp = Self.timestampFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"

        DispatchQueue.main.async {
            self.entries.append(line)
        }
        #endif
    }

    func clear() {
        #if DEBUG
        DispatchQueue.main.async {
            self.entries.removeAll()
        }
        #endif
    }

    func copyAll() -> String {
        entries.joined(separator: "\n")
    }

    private static let timestampFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
