import Foundation
import Combine

@MainActor
final class MicrophoneCheckViewModel: ObservableObject {
    let titleText = "Microphone check"
    let instructionText = "Say a few words"

    @Published private(set) var currentLevel: Float = 0
    @Published private(set) var hasDetectedSignal = false
    @Published private(set) var statusText: String?

    private let microphonePermissionClient: MicrophonePermissionClient
    private let levelMonitor: MicrophoneLevelMonitoring
    private let onStartPrayer: () -> Void
    private let onBack: () -> Void

    private var hasStarted = false

    init(
        microphonePermissionClient: MicrophonePermissionClient,
        levelMonitor: MicrophoneLevelMonitoring,
        onStartPrayer: @escaping () -> Void,
        onBack: @escaping () -> Void
    ) {
        self.microphonePermissionClient = microphonePermissionClient
        self.levelMonitor = levelMonitor
        self.onStartPrayer = onStartPrayer
        self.onBack = onBack
    }

    deinit {
        levelMonitor.stop()
    }

    func onAppear() {
        guard !hasStarted else { return }
        hasStarted = true

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
                        if level >= 0.01 {
                            self.hasDetectedSignal = true
                            self.statusText = "I’m hearing you"
                        }
                    }
                })
            } catch {
                self.statusText = error.localizedDescription
                return
            }

            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !self.hasDetectedSignal && self.statusText == nil {
                self.statusText = "I’m not hearing anything yet"
            }
        }
    }

    func onTapStartPraying() {
        levelMonitor.stop()
        onStartPrayer()
    }

    func onTapBack() {
        levelMonitor.stop()
        onBack()
    }
}
