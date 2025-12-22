import SwiftUI
import Domain

/// The main menu content view with OpenRouter Wrapped-inspired design.
/// Features purple-pink gradients, glassmorphism cards, and bold typography.
struct MenuContentView: View {
    let monitor: QuotaMonitor
    let appState: AppState

    @State private var selectedProvider: AIProvider = .claude
    @State private var isHoveringRefresh = false
    @State private var animateIn = false

    var body: some View {
        ZStack {
            // Gradient background
            AppTheme.backgroundGradient
                .ignoresSafeArea()

            // Subtle animated orbs in background
            backgroundOrbs

            VStack(spacing: 0) {
                // Header with branding
                headerView
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Provider Pills
                providerPills
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)

                // Main Content Area
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        metricsContent
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                }
                .frame(maxHeight: 280)

                // Bottom Action Bar
                actionBar
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
        }
        .frame(width: 380)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .task {
            await refresh()
            withAnimation(.easeOut(duration: 0.6)) {
                animateIn = true
            }
        }
    }

    // MARK: - Background Orbs

    private var backgroundOrbs: some View {
        GeometryReader { geo in
            ZStack {
                // Large purple orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.violetElectric.opacity(0.4),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 120
                        )
                    )
                    .frame(width: 240, height: 240)
                    .offset(x: -60, y: -80)
                    .blur(radius: 40)

                // Pink orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                AppTheme.pinkHot.opacity(0.35),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 100
                        )
                    )
                    .frame(width: 200, height: 200)
                    .offset(x: geo.size.width - 80, y: geo.size.height - 150)
                    .blur(radius: 30)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // Custom Provider Icon - changes based on selected provider
            ProviderIconView(provider: selectedProvider, size: 38)
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: selectedProvider)

            VStack(alignment: .leading, spacing: 2) {
                Text("ClaudeBar")
                    .font(AppTheme.titleFont(size: 18))
                    .foregroundStyle(.white)

                Text("AI Usage Monitor")
                    .font(AppTheme.captionFont(size: 11))
                    .foregroundStyle(.white.opacity(0.7))
            }

            Spacer()

            // Status Badge
            statusBadge
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : -10)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            // Animated pulse dot
            ZStack {
                Circle()
                    .fill(appState.overallStatus.themeColor)
                    .frame(width: 8, height: 8)

                Circle()
                    .stroke(appState.overallStatus.themeColor, lineWidth: 2)
                    .frame(width: 16, height: 16)
                    .scaleEffect(appState.isRefreshing ? 1.5 : 1.0)
                    .opacity(appState.isRefreshing ? 0 : 0.5)
                    .animation(
                        appState.isRefreshing
                            ? .easeOut(duration: 1.0).repeatForever(autoreverses: false)
                            : .default,
                        value: appState.isRefreshing
                    )
            }

            Text(statusText)
                .font(AppTheme.captionFont(size: 11))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(appState.overallStatus.themeColor.opacity(0.25))
                .overlay(
                    Capsule()
                        .stroke(appState.overallStatus.themeColor.opacity(0.5), lineWidth: 1)
                )
        )
    }

    private var statusText: String {
        if appState.isRefreshing { return "Syncing..." }
        return appState.overallStatus.badgeText
    }

    // MARK: - Provider Pills

    private var providerPills: some View {
        HStack(spacing: 8) {
            ForEach(AIProvider.allCases, id: \.self) { provider in
                WrappedProviderPill(
                    provider: provider,
                    isSelected: provider == selectedProvider,
                    hasData: appState.snapshots[provider] != nil
                ) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedProvider = provider
                    }
                }
            }
        }
        .opacity(animateIn ? 1 : 0)
        .offset(y: animateIn ? 0 : 10)
        .animation(.easeOut(duration: 0.5).delay(0.1), value: animateIn)
    }

    // MARK: - Metrics Content

    @ViewBuilder
    private var metricsContent: some View {
        if let snapshot = appState.snapshots[selectedProvider] {
            VStack(spacing: 12) {
                // Account info card
                if let email = snapshot.accountEmail {
                    accountCard(email: email, snapshot: snapshot)
                }

                // Stats Grid - Wrapped style with large numbers
                statsGrid(snapshot: snapshot)
            }
            .opacity(animateIn ? 1 : 0)
            .animation(.easeOut(duration: 0.5).delay(0.2), value: animateIn)
        } else if appState.isRefreshing {
            loadingState
        } else {
            emptyState
        }
    }

    private func accountCard(email: String, snapshot: UsageSnapshot) -> some View {
        HStack(spacing: 10) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(selectedProvider.themeGradient)
                    .frame(width: 32, height: 32)

                Text(String(email.prefix(1)).uppercased())
                    .font(AppTheme.titleFont(size: 14))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(email)
                    .font(AppTheme.bodyFont(size: 12))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("Updated \(snapshot.ageDescription)")
                    .font(AppTheme.captionFont(size: 10))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            // Stale indicator
            if snapshot.isStale {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.statusWarning)
            }
        }
        .glassCard(cornerRadius: 12, padding: 10)
    }

    private func statsGrid(snapshot: UsageSnapshot) -> some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ],
            spacing: 10
        ) {
            ForEach(Array(snapshot.quotas.enumerated()), id: \.element.quotaType) { index, quota in
                WrappedStatCard(quota: quota, delay: Double(index) * 0.08)
            }
        }
        .padding(.top, 4) // Room for hover scale effect
    }

    private var loadingState: some View {
        LoadingSpinnerView()
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.statusWarning.opacity(0.2))
                    .frame(width: 60, height: 60)

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(AppTheme.statusWarning)
            }

            Text("\(selectedProvider.name) Unavailable")
                .font(AppTheme.titleFont(size: 14))
                .foregroundStyle(.white)

            Text("Install CLI or check configuration")
                .font(AppTheme.captionFont(size: 11))
                .foregroundStyle(.white.opacity(0.6))
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .glassCard()
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 10) {
            // Dashboard Button
            WrappedActionButton(
                icon: "safari.fill",
                label: "Dashboard",
                gradient: selectedProvider.themeGradient
            ) {
                if let url = selectedProvider.dashboardURL {
                    NSWorkspace.shared.open(url)
                }
            }
            .keyboardShortcut("d")

            // Refresh Button
            WrappedActionButton(
                icon: appState.isRefreshing ? "arrow.trianglehead.2.counterclockwise.rotate.90" : "arrow.clockwise",
                label: appState.isRefreshing ? "Syncing" : "Refresh",
                gradient: AppTheme.accentGradient,
                isLoading: appState.isRefreshing
            ) {
                Task { await refresh() }
            }
            .keyboardShortcut("r")

            Spacer()

            // Quit Button
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.1))
                        .frame(width: 32, height: 32)

                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .help("Quit ClaudeBar")
            .keyboardShortcut("q")
        }
        .opacity(animateIn ? 1 : 0)
        .animation(.easeOut(duration: 0.5).delay(0.3), value: animateIn)
    }

    // MARK: - Actions

    private func refresh() async {
        guard !appState.isRefreshing else { return }

        appState.isRefreshing = true
        defer { appState.isRefreshing = false }

        do {
            appState.snapshots = try await monitor.refreshAll()
            appState.lastError = nil

            if appState.snapshots[selectedProvider] == nil,
               let first = appState.snapshots.keys.first {
                selectedProvider = first
            }
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}

// MARK: - Wrapped Provider Pill

struct WrappedProviderPill: View {
    let provider: AIProvider
    let isSelected: Bool
    let hasData: Bool
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: providerIcon)
                    .font(.system(size: 12, weight: .semibold))

                Text(provider.name)
                    .font(AppTheme.bodyFont(size: 12))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(provider.themeGradient)
                            .shadow(color: provider.themeColor.opacity(0.4), radius: 8, y: 2)
                    } else {
                        Capsule()
                            .fill(Color.white.opacity(isHovering ? 0.18 : 0.12))
                    }

                    Capsule()
                        .stroke(
                            isSelected ? Color.white.opacity(0.3) : Color.white.opacity(0.15),
                            lineWidth: 1
                        )
                }
            )
            .overlay(alignment: .topTrailing) {
                // Data indicator
                if hasData && !isSelected {
                    Circle()
                        .fill(AppTheme.statusHealthy)
                        .frame(width: 6, height: 6)
                        .offset(x: -4, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
    }

    private var providerIcon: String {
        switch provider {
        case .claude: return "brain.fill"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .gemini: return "sparkles"
        }
    }
}

// MARK: - Wrapped Stat Card

struct WrappedStatCard: View {
    let quota: UsageQuota
    let delay: Double

    @State private var isHovering = false
    @State private var animateProgress = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header row with icon, type, and badge
            HStack(alignment: .top, spacing: 0) {
                // Left side: icon and type label
                HStack(spacing: 5) {
                    Image(systemName: iconName)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(quota.status.themeColor)

                    Text(quota.quotaType.displayName.uppercased())
                        .font(AppTheme.captionFont(size: 8))
                        .foregroundStyle(.white.opacity(0.7))
                        .tracking(0.3)
                }

                Spacer(minLength: 4)

                // Status badge - fixed size, won't wrap
                Text(quota.status.badgeText)
                    .badge(quota.status.themeColor)
            }

            // Large percentage number
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text("\(Int(quota.percentRemaining))")
                    .font(AppTheme.statFont(size: 32))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text("%")
                    .font(AppTheme.titleFont(size: 16))
                    .foregroundStyle(.white.opacity(0.6))
            }

            // Progress bar with gradient
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.15))

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(AppTheme.progressGradient(for: quota.percentRemaining))
                        .frame(width: animateProgress ? geo.size.width * quota.percentRemaining / 100 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.7).delay(delay + 0.2), value: animateProgress)
                }
            }
            .frame(height: 5)

            // Reset info
            if let resetText = quota.resetText ?? quota.resetDescription {
                HStack(spacing: 3) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 7))

                    Text(resetText)
                        .font(AppTheme.captionFont(size: 8))
                }
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
            }
        }
        .padding(12)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(AppTheme.cardGradient)

                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(isHovering ? 0.35 : 0.25),
                                Color.white.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .scaleEffect(isHovering ? 1.015 : 1.0)
        .animation(.easeOut(duration: 0.15), value: isHovering)
        .onHover { isHovering = $0 }
        .onAppear {
            animateProgress = true
        }
    }

    private var iconName: String {
        switch quota.quotaType {
        case .session: return "bolt.fill"
        case .weekly: return "calendar.badge.clock"
        case .modelSpecific: return "cpu.fill"
        }
    }
}

// MARK: - Loading Spinner View

struct LoadingSpinnerView: View {
    @State private var isSpinning = false

    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.2), lineWidth: 3)
                    .frame(width: 50, height: 50)

                Circle()
                    .trim(from: 0, to: 0.3)
                    .stroke(
                        AppTheme.accentGradient,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )
                    .frame(width: 50, height: 50)
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        .linear(duration: 1).repeatForever(autoreverses: false),
                        value: isSpinning
                    )
            }

            Text("Fetching usage data...")
                .font(AppTheme.bodyFont(size: 13))
                .foregroundStyle(.white.opacity(0.8))
        }
        .frame(height: 140)
        .frame(maxWidth: .infinity)
        .glassCard()
        .onAppear {
            isSpinning = true
        }
    }
}

// MARK: - Wrapped Action Button

struct WrappedActionButton: View {
    let icon: String
    let label: String
    let gradient: LinearGradient
    var isLoading: Bool = false
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 14, height: 14)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 12, weight: .semibold))
                }

                Text(label)
                    .font(AppTheme.bodyFont(size: 12))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                ZStack {
                    Capsule()
                        .fill(isHovering ? gradient : LinearGradient(colors: [Color.white.opacity(0.15)], startPoint: .leading, endPoint: .trailing))

                    Capsule()
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                }
            )
            .shadow(color: isHovering ? gradient.stops.first?.color.opacity(0.3) ?? .clear : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .disabled(isLoading)
    }
}

// MARK: - Visual Effect Blur (macOS) - Kept for compatibility

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

// MARK: - Gradient Stops Extension

extension LinearGradient {
    var stops: [Gradient.Stop] {
        // Default empty - used for animation color extraction
        []
    }
}