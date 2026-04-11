import Foundation
import Combine

@MainActor
final class MicrophoneCheckViewModel: ObservableObject {
    let titleText = "Microphone check"
    let instructionText = "Say:\n\"Hail Mary, full of grace, the Lord is with you. Blessed are you among women.\""

    @Published private(set) var currentLevel: Float = 0
    @Published private(set) var hasDetectedSignal = false
    @Published private(set) var statusText: String? = "Listening..."
    @Published private(set) var calibration: InteractiveCalibration?

    private let microphonePermissionClient: MicrophonePermissionClient
    private let levelMonitor: MicrophoneLevelMonitoring
    private let onStartPrayer: (InteractiveCalibration?) -> Void
    private let onBack: () -> Void

    private var hasStarted = false
    private var sampleTimestamps: [Date] = []
    private var sampleLevels: [Float] = []
    private var maxObservedLevel: Float = 0

    init(
        microphonePermissionClient: MicrophonePermissionClient,
        levelMonitor: MicrophoneLevelMonitoring,
        onStartPrayer: @escaping (InteractiveCalibration?) -> Void,
        onBack: @escaping () -> Void
    ) {
        self.microphonePermissionClient = microphonePermissionClient
        self.levelMonitor = levelMonitor
        self.onStartPrayer = onStartPrayer
        self.onBack = onBack
    }

    deinit {
        let levelMonitor = self.levelMonitor
        Task { @MainActor in
            levelMonitor.stop()
        }
    }

    func onAppear() {
        guard !hasStarted else { return }
        hasStarted = true
        #if DEBUG
        DebugLog.shared.log("CALIBRATION started")
        #endif

        Task { [weak self] in
            guard let self else { return }
            let granted = await self.microphonePermissionClient.requestAccess()
            guard granted else {
                self.statusText = "Microphone access is required"
                return
            }

            do {
                try self.levelMonitor.start(onLevelChanged: { [weak self] level in
                    Task { @MainActor in
                        guard let self else { return }
                        self.currentLevel = min(max(level * 20, 0), 1)
                        self.maxObservedLevel = max(self.maxObservedLevel, level)
                        self.sampleTimestamps.append(Date())
                        self.sampleLevels.append(level)
                        if self.sampleLevels.count > 2_000 {
                            self.sampleLevels.removeFirst(self.sampleLevels.count - 2_000)
                            self.sampleTimestamps.removeFirst(self.sampleTimestamps.count - 2_000)
                        }
                        if level >= 0.01 {
                            self.hasDetectedSignal = true
                        }

                        if self.hasDetectedSignal {
                            self.statusText = self.maxObservedLevel >= 0.02
                                ? "Good — I can hear you"
                                : "A little quiet, but usable"
                        }
                    }
                })
            } catch {
                self.statusText = error.localizedDescription
                return
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !self.hasDetectedSignal {
                self.statusText = "I’m not hearing much yet"
            }
        }
    }

    func onTapStartPraying() {
        levelMonitor.stop()
        let estimate = InteractiveCalibrationHeuristics.estimate(
            levelSamples: sampleLevels,
            sampleIntervalSec: averageSampleIntervalSec(),
            startTimeoutSec: InteractivePrayerPolicy.default.userResponseTimeoutSec
        )
        calibration = estimate.calibration
        #if DEBUG
        DebugLog.shared.log(String(format: "CALIBRATION noiseFloor=%.4f", estimate.noiseFloor))
        DebugLog.shared.log(String(format: "CALIBRATION speechLevel=%.4f", estimate.speechLevel))
        if let calibration = estimate.calibration {
            DebugLog.shared.log(String(format: "CALIBRATION speechStartThreshold=%.4f", calibration.speechStartThreshold))
            DebugLog.shared.log(String(format: "CALIBRATION speechContinueThreshold=%.4f", calibration.speechContinueThreshold))
            DebugLog.shared.log(String(format: "CALIBRATION completionSilenceSec=%.2f", calibration.completionSilenceSec))
        } else {
            DebugLog.shared.log(String(format: "CALIBRATION speechStartThreshold=%.4f", UtteranceConfig.default.speechStartThreshold))
            DebugLog.shared.log(String(format: "CALIBRATION speechContinueThreshold=%.4f", UtteranceConfig.default.speechContinueThreshold))
            DebugLog.shared.log(String(format: "CALIBRATION completionSilenceSec=%.2f", UtteranceConfig.default.completionSilenceSec))
        }
        DebugLog.shared.log("CALIBRATION quality=\(estimate.quality.rawValue)")
        #endif
        onStartPrayer(calibration)
    }

    func onTapBack() {
        levelMonitor.stop()
        onBack()
    }

    private func averageSampleIntervalSec() -> TimeInterval {
        guard sampleTimestamps.count >= 2 else { return 0.02 }
        let duration = sampleTimestamps.last!.timeIntervalSince(sampleTimestamps.first!)
        return max(0.01, duration / Double(sampleTimestamps.count - 1))
    }
}
