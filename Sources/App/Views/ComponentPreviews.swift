import SwiftUI
import Domain

// MARK: - Component Previews
// Preview all UI components in one place

// MARK: - Provider Icons Preview

#Preview("Provider Icons") {
    HStack(spacing: 40) {
        VStack(spacing: 8) {
            ProviderIconView(provider: .claude, size: 32)
            Text("Claude")
                .font(.caption)
                .foregroundStyle(.white)
        }
        VStack(spacing: 8) {
            ProviderIconView(provider: .codex, size: 32)
            Text("Codex")
                .font(.caption)
                .foregroundStyle(.white)
        }
        VStack(spacing: 8) {
            ProviderIconView(provider: .gemini, size: 32)
            Text("Gemini")
                .font(.caption)
                .foregroundStyle(.white)
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Provider Pills Preview

#Preview("Provider Pills") {
    VStack(spacing: 20) {
        // Selected states
        HStack(spacing: 8) {
            WrappedProviderPill(provider: .claude, isSelected: true, hasData: true) {}
            WrappedProviderPill(provider: .codex, isSelected: false, hasData: true) {}
            WrappedProviderPill(provider: .gemini, isSelected: false, hasData: false) {}
        }

        // Different selection
        HStack(spacing: 8) {
            WrappedProviderPill(provider: .claude, isSelected: false, hasData: true) {}
            WrappedProviderPill(provider: .codex, isSelected: true, hasData: true) {}
            WrappedProviderPill(provider: .gemini, isSelected: false, hasData: true) {}
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Stat Cards Preview

#Preview("Stat Cards - Healthy") {
    let healthyQuota = UsageQuota(
        percentRemaining: 85,
        quotaType: .session,
        provider: .claude,
        resetText: "Resets 11am"
    )

    return WrappedStatCard(quota: healthyQuota, delay: 0)
        .frame(width: 160)
        .padding(20)
        .background(AppTheme.backgroundGradient)
}

#Preview("Stat Cards - Warning") {
    let warningQuota = UsageQuota(
        percentRemaining: 35,
        quotaType: .weekly,
        provider: .claude,
        resetText: "Resets Dec 25"
    )

    return WrappedStatCard(quota: warningQuota, delay: 0)
        .frame(width: 160)
        .padding(20)
        .background(AppTheme.backgroundGradient)
}

#Preview("Stat Cards - Critical") {
    let criticalQuota = UsageQuota(
        percentRemaining: 12,
        quotaType: .modelSpecific("Opus"),
        provider: .claude,
        resetText: "Resets in 2h"
    )

    WrappedStatCard(quota: criticalQuota, delay: 0)
        .frame(width: 160)
        .padding(20)
        .background(AppTheme.backgroundGradient)
}

#Preview("Stat Cards Grid") {
    let quotas = [
        UsageQuota(percentRemaining: 94, quotaType: .session, provider: .claude, resetText: "Resets 11am"),
        UsageQuota(percentRemaining: 33, quotaType: .weekly, provider: .claude, resetText: "Resets Dec 25"),
        UsageQuota(percentRemaining: 99, quotaType: .modelSpecific("Opus"), provider: .claude, resetText: "Resets Dec 25"),
        UsageQuota(percentRemaining: 5, quotaType: .modelSpecific("Sonnet"), provider: .claude, resetText: "Resets in 1h"),
    ]

    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
        ForEach(Array(quotas.enumerated()), id: \.offset) { index, quota in
            WrappedStatCard(quota: quota, delay: Double(index) * 0.1)
        }
    }
    .padding(20)
    .frame(width: 360)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Status Badges Preview

#Preview("Status Badges") {
    VStack(spacing: 16) {
        HStack(spacing: 12) {
            Text("HEALTHY").badge(AppTheme.statusHealthy)
            Text("WARNING").badge(AppTheme.statusWarning)
            Text("LOW").badge(AppTheme.statusCritical)
            Text("EMPTY").badge(AppTheme.statusDepleted)
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Action Buttons Preview

#Preview("Action Buttons") {
    HStack(spacing: 12) {
        WrappedActionButton(
            icon: "safari.fill",
            label: "Dashboard",
            gradient: AIProvider.claude.themeGradient
        ) {}

        WrappedActionButton(
            icon: "arrow.clockwise",
            label: "Refresh",
            gradient: AppTheme.accentGradient
        ) {}

        WrappedActionButton(
            icon: "arrow.clockwise",
            label: "Syncing",
            gradient: AppTheme.accentGradient,
            isLoading: true
        ) {}
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Loading Spinner Preview

#Preview("Loading Spinner") {
    LoadingSpinnerView()
        .frame(width: 300)
        .background(AppTheme.backgroundGradient)
}

// MARK: - Glass Card Preview

#Preview("Glass Cards") {
    VStack(spacing: 16) {
        Text("Glass Card Style")
            .font(.headline)
            .foregroundStyle(.white)
            .glassCard()

        HStack {
            Image(systemName: "person.circle.fill")
            Text("user@example.com")
            Spacer()
            Text("Just now")
                .foregroundStyle(.secondary)
        }
        .font(.caption)
        .foregroundStyle(.white)
        .glassCard(cornerRadius: 12, padding: 10)
    }
    .padding(40)
    .frame(width: 300)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Theme Colors Preview

#Preview("Theme Colors") {
    VStack(spacing: 20) {
        Text("Provider Colors")
            .font(.headline)
            .foregroundStyle(.white)

        HStack(spacing: 20) {
            VStack {
                Circle().fill(AIProvider.claude.themeColor).frame(width: 40, height: 40)
                Text("Claude").font(.caption).foregroundStyle(.white)
            }
            VStack {
                Circle().fill(AIProvider.codex.themeColor).frame(width: 40, height: 40)
                Text("Codex").font(.caption).foregroundStyle(.white)
            }
            VStack {
                Circle().fill(AIProvider.gemini.themeColor).frame(width: 40, height: 40)
                Text("Gemini").font(.caption).foregroundStyle(.white)
            }
        }

        Text("Status Colors")
            .font(.headline)
            .foregroundStyle(.white)

        HStack(spacing: 20) {
            VStack {
                Circle().fill(AppTheme.statusHealthy).frame(width: 40, height: 40)
                Text("Healthy").font(.caption).foregroundStyle(.white)
            }
            VStack {
                Circle().fill(AppTheme.statusWarning).frame(width: 40, height: 40)
                Text("Warning").font(.caption).foregroundStyle(.white)
            }
            VStack {
                Circle().fill(AppTheme.statusCritical).frame(width: 40, height: 40)
                Text("Critical").font(.caption).foregroundStyle(.white)
            }
            VStack {
                Circle().fill(AppTheme.statusDepleted).frame(width: 40, height: 40)
                Text("Depleted").font(.caption).foregroundStyle(.white)
            }
        }
    }
    .padding(40)
    .background(AppTheme.backgroundGradient)
}

// MARK: - Full Header Preview

#Preview("Header Section") {
    VStack(spacing: 16) {
        // Header mock
        HStack(spacing: 12) {
            ProviderIconView(provider: .claude, size: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClaudeBar")
                    .font(AppTheme.titleFont(size: 18))
                    .foregroundStyle(.white)

                Text("AI Usage Monitor")
                    .font(AppTheme.captionFont(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Status badge
            HStack(spacing: 6) {
                Circle()
                    .fill(AppTheme.statusHealthy)
                    .frame(width: 8, height: 8)
                Text("HEALTHY")
                    .font(AppTheme.captionFont(size: 11))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(AppTheme.statusHealthy.opacity(0.25))
            )
        }
        .padding(.horizontal, 16)

        // Provider pills
        HStack(spacing: 8) {
            WrappedProviderPill(provider: .claude, isSelected: true, hasData: true) {}
            WrappedProviderPill(provider: .codex, isSelected: false, hasData: true) {}
            WrappedProviderPill(provider: .gemini, isSelected: false, hasData: false) {}
        }
    }
    .padding(.vertical, 20)
    .frame(width: 380)
    .background(AppTheme.backgroundGradient)
}
