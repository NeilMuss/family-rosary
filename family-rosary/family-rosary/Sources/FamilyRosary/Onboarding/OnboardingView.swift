import SwiftUI

private struct OnboardingStep {
    let title: String
    let bodyLines: [String]
    let buttonTitle: String
}

struct OnboardingView: View {
    private let steps: [OnboardingStep] = [
        OnboardingStep(
            title: "Pray the Rosary with the voices of your family.",
            bodyLines: [],
            buttonTitle: "Begin"
        ),
        OnboardingStep(
            title: "You'll just need a short voice recording.",
            bodyLines: ["You can use the Voice Memos app on your phone."],
            buttonTitle: "Next"
        ),
        OnboardingStep(
            title: "Open Voice Memos",
            bodyLines: [
                "Tap the red record button and say:",
                "\"Hail Mary, full of grace, the Lord is with thee...\"",
                "Then stop the recording and come back here."
            ],
            buttonTitle: "I recorded it"
        ),
        OnboardingStep(
            title: "In Voice Memos:",
            bodyLines: [
                "1. Tap your recording",
                "2. Tap the share button",
                "3. Choose 'Family Rosary'"
            ],
            buttonTitle: "I'll try it"
        )
    ]

    let onDone: () -> Void
    let onSkip: () -> Void

    @State private var stepIndex = 0

    var body: some View {
        VStack(spacing: 28) {
            HStack {
                Spacer()

                Button("Skip") {
                    onSkip()
                }
                .buttonStyle(LiturgicalSecondaryButtonStyle())
            }

            Spacer(minLength: 12)

            Text("Welcome")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(LiturgicalTheme.textSecondary)

            Text(currentStep.title)
                .font(.system(size: 34, weight: .bold))
                .multilineTextAlignment(.center)
                .foregroundStyle(LiturgicalTheme.textPrimary)

            if currentStep.bodyLines.isEmpty == false {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(currentStep.bodyLines, id: \.self) { line in
                        Text(line)
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(LiturgicalTheme.textSecondary)
                            .multilineTextAlignment(stepIndex == 3 ? .leading : .center)
                            .frame(maxWidth: .infinity, alignment: stepIndex == 3 ? .leading : .center)
                    }
                }
                .liturgicalSurface()
            }

            HStack(spacing: 8) {
                ForEach(steps.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == stepIndex ? LiturgicalTheme.accent.opacity(0.7) : LiturgicalTheme.surfaceBorder)
                        .frame(width: index == stepIndex ? 28 : 10, height: 6)
                }
            }

            Spacer()

            Button(currentStep.buttonTitle) {
                advance()
            }
            .buttonStyle(LiturgicalPrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liturgicalScreen(showsCandlePlaceholder: true)
        .animation(.easeInOut(duration: 0.36), value: stepIndex)
    }

    private var currentStep: OnboardingStep {
        steps[stepIndex]
    }

    private func advance() {
        if stepIndex == steps.count - 1 {
            onDone()
        } else {
            stepIndex += 1
        }
    }
}
