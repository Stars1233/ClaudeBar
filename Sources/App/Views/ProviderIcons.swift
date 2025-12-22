import SwiftUI

// MARK: - Provider Icon View

/// A view that displays the appropriate icon for each AI provider
/// Icons fill the entire circle like OpenRouter's design
struct ProviderIconView: View {
    let providerId: String
    var size: CGFloat = 24
    var showGlow: Bool = true

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            if showGlow {
                // Subtle glow behind icon - adapts to theme
                Circle()
                    .fill(AppTheme.providerColor(for: providerId, scheme: colorScheme).opacity(colorScheme == .dark ? 0.3 : 0.2))
                    .frame(width: size * 1.3, height: size * 1.3)
                    .blur(radius: size * 0.3)
            }

            // Provider icon - fills the entire circle with adaptive border
            if let nsImage = loadProviderIcon(for: providerId) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                colorScheme == .dark
                                    ? Color.white.opacity(0.6)
                                    : AppTheme.purpleVibrant(for: colorScheme).opacity(0.3),
                                lineWidth: 2
                            )
                    )
                    .shadow(
                        color: colorScheme == .dark
                            ? .black.opacity(0.15)
                            : AppTheme.purpleDeep(for: colorScheme).opacity(0.15),
                        radius: 3,
                        y: 1
                    )
            }
        }
    }

    private func loadProviderIcon(for providerId: String) -> NSImage? {
        let assetName = AppTheme.providerIconAssetName(for: providerId)
        // Load SVG from SPM bundle resources
        if let url = Bundle.module.url(forResource: assetName, withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

// MARK: - Preview

#Preview("Provider Icons - Dark") {
    HStack(spacing: 30) {
        VStack {
            ProviderIconView(providerId: "claude", size: 40)
            Text("Claude")
                .font(.caption)
                .foregroundStyle(.white)
        }
        VStack {
            ProviderIconView(providerId: "codex", size: 40)
            Text("Codex")
                .font(.caption)
                .foregroundStyle(.white)
        }
        VStack {
            ProviderIconView(providerId: "gemini", size: 40)
            Text("Gemini")
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient(for: .dark))
    .preferredColorScheme(.dark)
}

#Preview("Provider Icons - Light") {
    HStack(spacing: 30) {
        VStack {
            ProviderIconView(providerId: "claude", size: 40)
            Text("Claude")
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary(for: .light))
        }
        VStack {
            ProviderIconView(providerId: "codex", size: 40)
            Text("Codex")
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary(for: .light))
        }
        VStack {
            ProviderIconView(providerId: "gemini", size: 40)
            Text("Gemini")
                .font(.caption)
                .foregroundStyle(AppTheme.textPrimary(for: .light))
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient(for: .light))
    .preferredColorScheme(.light)
}

#Preview("Provider Icons - Sizes") {
    HStack(spacing: 20) {
        ProviderIconView(providerId: "claude", size: 24)
        ProviderIconView(providerId: "claude", size: 32)
        ProviderIconView(providerId: "claude", size: 40)
        ProviderIconView(providerId: "claude", size: 48)
    }
    .padding(40)
    .background(AppTheme.backgroundGradient(for: .dark))
    .preferredColorScheme(.dark)
}
