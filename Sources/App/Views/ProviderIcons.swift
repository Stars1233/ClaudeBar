import SwiftUI
import Domain

// MARK: - Provider Icon View

/// A view that displays the appropriate icon for each AI provider
/// Icons fill the entire circle like OpenRouter's design
struct ProviderIconView: View {
    let provider: AIProvider
    var size: CGFloat = 24
    var showGlow: Bool = true

    var body: some View {
        ZStack {
            if showGlow {
                // Subtle glow behind icon
                Circle()
                    .fill(provider.themeColor.opacity(0.3))
                    .frame(width: size * 1.3, height: size * 1.3)
                    .blur(radius: size * 0.3)
            }

            // Provider icon - fills the entire circle with white border
            if let nsImage = loadProviderIcon(for: provider) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(0.15), radius: 3, y: 1)
            }
        }
    }

    private func loadProviderIcon(for provider: AIProvider) -> NSImage? {
        // Load SVG from SPM bundle resources
        if let url = Bundle.module.url(forResource: provider.iconAssetName, withExtension: "svg") {
            return NSImage(contentsOf: url)
        }
        return nil
    }
}

// MARK: - AIProvider Icon Names

extension AIProvider {
    /// The resource name for this provider's icon (without extension)
    var iconAssetName: String {
        switch self {
        case .claude: "ClaudeIcon"
        case .codex: "CodexIcon"
        case .gemini: "GeminiIcon"
        }
    }
}

// MARK: - Preview

#Preview("Provider Icons") {
    HStack(spacing: 30) {
        VStack {
            ProviderIconView(provider: .claude, size: 40)
            Text("Claude")
                .font(.caption)
                .foregroundStyle(.white)
        }
        VStack {
            ProviderIconView(provider: .codex, size: 40)
            Text("Codex")
                .font(.caption)
                .foregroundStyle(.white)
        }
        VStack {
            ProviderIconView(provider: .gemini, size: 40)
            Text("Gemini")
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}

#Preview("Provider Icons - Sizes") {
    HStack(spacing: 20) {
        ProviderIconView(provider: .claude, size: 24)
        ProviderIconView(provider: .claude, size: 32)
        ProviderIconView(provider: .claude, size: 40)
        ProviderIconView(provider: .claude, size: 48)
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}
