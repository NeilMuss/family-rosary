import Foundation

protocol Sleeper {
    func sleep(ms: Int) async
}

struct RealSleeper: Sleeper {
    func sleep(ms: Int) async {
        guard ms > 0 else { return }
        try? await Task.sleep(nanoseconds: UInt64(ms) * 1_000_000)
    }
}
