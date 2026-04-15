import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
protocol IdleTimerControlling: AnyObject {
    func disableIdleTimer()
    func restoreIdleTimer()
}

@MainActor
final class ApplicationIdleTimerController: IdleTimerControlling {
    #if canImport(UIKit)
    private let application: UIApplication
    #endif
    private var disableCount = 0
    private var previousIdleTimerDisabled: Bool?

    init(
        #if canImport(UIKit)
        application: UIApplication = .shared
        #endif
    ) {
        #if canImport(UIKit)
        self.application = application
        #endif
    }

    func disableIdleTimer() {
        DebugLog.shared.log("IDLE_TIMER_DISABLE_BEGIN")
        if disableCount == 0 {
            #if canImport(UIKit)
            previousIdleTimerDisabled = application.isIdleTimerDisabled
            application.isIdleTimerDisabled = true
            #endif
        }
        disableCount += 1
        DebugLog.shared.log("IDLE_TIMER_DISABLED")
    }

    func restoreIdleTimer() {
        DebugLog.shared.log("IDLE_TIMER_RESTORE_BEGIN")
        guard disableCount > 0 else {
            DebugLog.shared.log("IDLE_TIMER_RESTORED")
            return
        }

        disableCount -= 1
        if disableCount == 0 {
            #if canImport(UIKit)
            application.isIdleTimerDisabled = previousIdleTimerDisabled ?? false
            #endif
            previousIdleTimerDisabled = nil
        }
        DebugLog.shared.log("IDLE_TIMER_RESTORED")
    }
}
