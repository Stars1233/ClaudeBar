import SwiftUI

// MARK: - ClaudeBar App Theme
// Purple-pink gradients with glassmorphism, inspired by OpenRouter Wrapped

enum AppTheme {
    // MARK: - Core Colors

    /// Deep purple base
    static let purpleDeep = Color(red: 0.38, green: 0.22, blue: 0.72)

    /// Vibrant purple
    static let purpleVibrant = Color(red: 0.55, green: 0.32, blue: 0.85)

    /// Hot pink accent
    static let pinkHot = Color(red: 0.85, green: 0.35, blue: 0.65)

    /// Soft magenta
    static let magentaSoft = Color(red: 0.78, green: 0.42, blue: 0.75)

    /// Electric violet
    static let violetElectric = Color(red: 0.62, green: 0.28, blue: 0.98)

    /// Coral accent for highlights
    static let coralAccent = Color(red: 0.98, green: 0.55, blue: 0.45)

    /// Golden accent
    static let goldenGlow = Color(red: 0.98, green: 0.78, blue: 0.35)

    /// Teal accent
    static let tealBright = Color(red: 0.35, green: 0.85, blue: 0.78)

    // MARK: - Status Colors (Wrapped Style)

    static let statusHealthy = Color(red: 0.35, green: 0.92, blue: 0.68)
    static let statusWarning = Color(red: 0.98, green: 0.72, blue: 0.35)
    static let statusCritical = Color(red: 0.98, green: 0.42, blue: 0.52)
    static let statusDepleted = Color(red: 0.85, green: 0.25, blue: 0.35)

    // MARK: - Gradients

    /// Main background gradient
    static let backgroundGradient = LinearGradient(
        colors: [
            purpleDeep,
            purpleVibrant,
            pinkHot.opacity(0.8)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Card background gradient
    static let cardGradient = LinearGradient(
        colors: [
            Color.white.opacity(0.18),
            Color.white.opacity(0.08)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Accent gradient for highlights
    static let accentGradient = LinearGradient(
        colors: [coralAccent, pinkHot],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Provider pill gradient
    static let pillGradient = LinearGradient(
        colors: [
            magentaSoft.opacity(0.6),
            pinkHot.opacity(0.4)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Progress bar gradient
    static func progressGradient(for percent: Double) -> LinearGradient {
        let colors: [Color] = switch percent {
        case 0..<20:
            [statusCritical, statusDepleted]
        case 20..<50:
            [statusWarning, coralAccent]
        default:
            [tealBright, statusHealthy]
        }
        return LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing)
    }

    // MARK: - Typography

    /// Large stat number font
    static func statFont(size: CGFloat) -> Font {
        .system(size: size, weight: .heavy, design: .rounded)
    }

    /// Title font
    static func titleFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Body text font
    static func bodyFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .rounded)
    }

    /// Caption font
    static func captionFont(size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .rounded)
    }

    // MARK: - Glass Effect

    static let glassBackground = Color.white.opacity(0.12)
    static let glassBorder = Color.white.opacity(0.25)
    static let glassHighlight = Color.white.opacity(0.35)
}

// MARK: - Glass Card Modifier

struct GlassCardStyle: ViewModifier {
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                ZStack {
                    // Base glass layer
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(AppTheme.cardGradient)

                    // Inner highlight
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(AppTheme.glassBorder, lineWidth: 1)

                    // Top edge shine
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    AppTheme.glassHighlight,
                                    Color.clear,
                                    Color.clear
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            lineWidth: 1
                        )
                }
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, padding: CGFloat = 12) -> some View {
        modifier(GlassCardStyle(cornerRadius: cornerRadius, padding: padding))
    }
}

// MARK: - Shimmer Animation Modifier

struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            Color.white.opacity(0.15),
                            Color.white.opacity(0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.5)
                    .offset(x: phase * geo.size.width * 1.5 - geo.size.width * 0.25)
                }
                .mask(content)
            )
            .onAppear {
                withAnimation(.linear(duration: 2.5).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerEffect())
    }
}

// MARK: - Glow Effect Modifier

struct GlowEffect: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.5), radius: radius / 2)
            .shadow(color: color.opacity(0.3), radius: radius)
    }
}

extension View {
    func glow(_ color: Color, radius: CGFloat = 10) -> some View {
        modifier(GlowEffect(color: color, radius: radius))
    }
}

// MARK: - Badge Style

struct BadgeStyle: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        content
            .font(AppTheme.captionFont(size: 8))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(color.opacity(0.9))
            )
            .fixedSize()
    }
}

extension View {
    func badge(_ color: Color) -> some View {
        modifier(BadgeStyle(color: color))
    }
}

// MARK: - Provider Colors

extension AIProvider {
    var themeColor: Color {
        switch self {
        case .claude:
            AppTheme.coralAccent
        case .codex:
            AppTheme.tealBright
        case .gemini:
            AppTheme.goldenGlow
        }
    }

    var themeGradient: LinearGradient {
        switch self {
        case .claude:
            LinearGradient(
                colors: [AppTheme.coralAccent, AppTheme.pinkHot],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .codex:
            LinearGradient(
                colors: [AppTheme.tealBright, Color(red: 0.25, green: 0.65, blue: 0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .gemini:
            LinearGradient(
                colors: [AppTheme.goldenGlow, Color(red: 0.95, green: 0.55, blue: 0.35)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Icon displayed in the header - larger, more prominent
    var headerIcon: String {
        switch self {
        case .claude:
            "brain.head.profile.fill"
        case .codex:
            "terminal.fill"
        case .gemini:
            "sparkles"
        }
    }
}

// MARK: - Status Theme Colors

import Domain

extension QuotaStatus {
    var themeColor: Color {
        switch self {
        case .healthy:
            AppTheme.statusHealthy
        case .warning:
            AppTheme.statusWarning
        case .critical:
            AppTheme.statusCritical
        case .depleted:
            AppTheme.statusDepleted
        }
    }

    var badgeText: String {
        switch self {
        case .healthy: "HEALTHY"
        case .warning: "WARNING"
        case .critical: "LOW"
        case .depleted: "EMPTY"
        }
    }
}