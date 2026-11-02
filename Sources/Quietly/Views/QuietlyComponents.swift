import SwiftUI

extension Color {
    static let quietlyIndigo = Color(red: 0.35, green: 0.32, blue: 0.86)
    static let quietlyMint = Color(red: 0.20, green: 0.76, blue: 0.61)
}

struct QuietlyLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [.quietlyIndigo, Color(red: 0.22, green: 0.65, blue: 0.72)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "speaker.wave.2.fill")
                .font(.system(size: size * 0.43, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.quietlyIndigo.opacity(0.26), radius: size * 0.16, y: size * 0.08)
        .accessibilityHidden(true)
    }
}

extension View {
    func quietCard(cornerRadius: CGFloat) -> some View {
        background(.regularMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.075))
            }
            .shadow(color: Color.black.opacity(0.035), radius: 10, y: 4)
    }
}

struct QuietIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 32, height: 32)
            .foregroundStyle(configuration.isPressed ? Color.quietlyIndigo : Color.primary)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.10 : 0.055),
                in: RoundedRectangle(cornerRadius: 9, style: .continuous)
            )
            .contentShape(Rectangle())
    }
}

struct QuietPrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(.white)
            .background(
                Color.white.opacity(
                    isEnabled
                        ? (configuration.isPressed ? 0.14 : 0.20)
                        : 0.08
                ),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled ? 0.18 : 0.08))
            }
            .opacity(isEnabled ? 1 : 0.6)
    }
}

struct QuietSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .foregroundStyle(.primary)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.12 : 0.07),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .opacity(isEnabled ? 1 : 0.45)
    }
}
