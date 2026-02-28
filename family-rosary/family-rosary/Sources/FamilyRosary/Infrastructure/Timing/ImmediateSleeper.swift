/// No-op sleeper for fast debug/dev playback runs without waiting on pauses.
import Foundation

struct ImmediateSleeper: Sleeper {
    func sleep(ms: Int) async {
        // Intentionally no-op to keep iteration and tests fast in debug paths.
    }
}
