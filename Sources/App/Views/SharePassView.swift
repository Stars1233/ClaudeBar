import SwiftUI
import Domain

/// A simple overlay that shows the referral link with copy functionality.
struct SharePassOverlay: View {
    let pass: ClaudePass
    let onDismiss: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isChristmasTheme) private var isChristmas
    @State private var copied = false

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Card
            VStack(spacing: 14) {
                // Header
                HStack {
                    Image(systemName: "gift.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isChristmas ? AppTheme.christmasGold : AppTheme.purpleVibrant(for: colorScheme))

                    Text("Share Claude Code")
                        .font(AppTheme.titleFont(size: 14))
                        .foregroundStyle(isChristmas ? AppTheme.christmasTextPrimary : AppTheme.textPrimary(for: colorScheme))

                    Spacer()

                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(AppTheme.textTertiary(for: colorScheme))
                    }
                    .buttonStyle(.plain)
                }

                // Referral Link
                HStack(spacing: 8) {
                    Text(pass.referralURL.absoluteString)
                        .font(AppTheme.bodyFont(size: 11))
                        .foregroundStyle(isChristmas ? AppTheme.christmasTextPrimary : AppTheme.textPrimary(for: colorScheme))
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        copyToClipboard()
                    } label: {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(copied
                                ? AppTheme.statusHealthy(for: colorScheme)
                                : (isChristmas ? AppTheme.christmasGold : AppTheme.purpleVibrant(for: colorScheme)))
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.04))
                )

                // Action buttons
                HStack(spacing: 10) {
                    Button {
                        copyToClipboard()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .semibold))
                            Text(copied ? "Copied!" : "Copy Link")
                                .font(AppTheme.bodyFont(size: 11))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            Capsule()
                                .fill(
                                    isChristmas
                                        ? AppTheme.christmasAccentGradient
                                        : AppTheme.accentGradient(for: colorScheme)
                                )
                        )
                    }
                    .buttonStyle(.plain)

                    Button {
                        NSWorkspace.shared.open(pass.referralURL)
                        onDismiss()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "safari")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Open")
                                .font(AppTheme.bodyFont(size: 11))
                        }
                        .foregroundStyle(isChristmas ? AppTheme.christmasTextPrimary : AppTheme.textPrimary(for: colorScheme))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(isChristmas ? AppTheme.christmasGlassBackground : AppTheme.glassBackground(for: colorScheme))
                                .overlay(
                                    Capsule()
                                        .stroke(
                                            isChristmas ? AppTheme.christmasGlassBorder : AppTheme.glassBorder(for: colorScheme),
                                            lineWidth: 1
                                        )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }

                // Help text
                Text("Share a free week of Claude Code with friends")
                    .font(AppTheme.captionFont(size: 10))
                    .foregroundStyle(AppTheme.textTertiary(for: colorScheme))
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isChristmas ? AppTheme.christmasGlassBackground : AppTheme.glassBackground(for: colorScheme))
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(
                                isChristmas ? AppTheme.christmasGlassBorder : AppTheme.glassBorder(for: colorScheme),
                                lineWidth: 1
                            )
                    )
                    .shadow(color: Color.black.opacity(0.4), radius: 20, y: 10)
            )
            .padding(.horizontal, 24)
        }
        .transition(.opacity)
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(pass.referralURL.absoluteString, forType: .string)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            copied = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(.easeOut(duration: 0.3)) {
                copied = false
            }
        }
    }
}

// MARK: - Preview

#Preview("SharePassOverlay") {
    ZStack {
        AppTheme.backgroundGradient(for: .dark)

        SharePassOverlay(
            pass: ClaudePass(
                referralURL: URL(string: "https://claude.ai/referral/DJ_kWX90Xw")!
            ),
            onDismiss: {}
        )
    }
    .frame(width: 380, height: 400)
}
