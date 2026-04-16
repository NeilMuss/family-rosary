import SwiftUI

struct LiturgicalTheme {
    static let backgroundPrimary = Color(hex: "0B0B0C")
    static let backgroundElevated = Color(hex: "111112")
    static let textPrimary = Color(hex: "F2F2F2")
    static let textSecondary = Color(hex: "A8A8A8")
    static let accent = Color(hex: "D4AF37")
    static let divider = textPrimary.opacity(0.08)
    static let surfaceBorder = textPrimary.opacity(0.10)
    static let subtleAccentFill = accent.opacity(0.14)
    static let strongAccentFill = accent.opacity(0.20)
    static let error = Color(red: 0.86, green: 0.48, blue: 0.45)
}

struct LiturgicalBackdrop: View {
    var showsCandlePlaceholder: Bool = false

    var body: some View {
        ZStack {
            LiturgicalTheme.backgroundPrimary

            LinearGradient(
                colors: [
                    LiturgicalTheme.backgroundPrimary,
                    LiturgicalTheme.backgroundElevated.opacity(0.92)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            if showsCandlePlaceholder {
                // Placeholder hook for a future candle/video background layer.
                RadialGradient(
                    colors: [
                        LiturgicalTheme.accent.opacity(0.10),
                        LiturgicalTheme.accent.opacity(0.03),
                        .clear
                    ],
                    center: .top,
                    startRadius: 12,
                    endRadius: 260
                )
                .blur(radius: 8)
                .offset(y: -40)
            }
        }
        .ignoresSafeArea()
    }
}

struct LiturgicalPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LiturgicalTheme.textPrimary)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LiturgicalTheme.strongAccentFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LiturgicalTheme.accent.opacity(0.48), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.easeInOut(duration: 0.22), value: configuration.isPressed)
    }
}

struct LiturgicalSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LiturgicalTheme.textSecondary)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(LiturgicalTheme.backgroundElevated.opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeInOut(duration: 0.22), value: configuration.isPressed)
    }
}

struct LiturgicalChoiceButtonStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(LiturgicalTheme.textPrimary)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isSelected ? LiturgicalTheme.subtleAccentFill : LiturgicalTheme.backgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? LiturgicalTheme.accent.opacity(0.42) : LiturgicalTheme.surfaceBorder, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.84 : 1)
            .animation(.easeInOut(duration: 0.24), value: configuration.isPressed)
    }
}

private struct LiturgicalScreenModifier: ViewModifier {
    let showsCandlePlaceholder: Bool

    func body(content: Content) -> some View {
        ZStack {
            LiturgicalBackdrop(showsCandlePlaceholder: showsCandlePlaceholder)
            content
        }
        .tint(LiturgicalTheme.accent)
        .foregroundStyle(LiturgicalTheme.textPrimary)
        .preferredColorScheme(.dark)
    }
}

private struct LiturgicalSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LiturgicalTheme.backgroundElevated.opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
            )
    }
}

private struct LiturgicalInputModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LiturgicalTheme.backgroundElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(LiturgicalTheme.surfaceBorder, lineWidth: 1)
            )
            .foregroundStyle(LiturgicalTheme.textPrimary)
    }
}

extension View {
    func liturgicalScreen(showsCandlePlaceholder: Bool = false) -> some View {
        modifier(LiturgicalScreenModifier(showsCandlePlaceholder: showsCandlePlaceholder))
    }

    func liturgicalSurface() -> some View {
        modifier(LiturgicalSurfaceModifier())
    }

    func liturgicalInput() -> some View {
        modifier(LiturgicalInputModifier())
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)

        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (r, g, b) = (0, 0, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: 1
        )
    }
}
