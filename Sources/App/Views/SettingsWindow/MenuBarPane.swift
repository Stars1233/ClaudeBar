import SwiftUI
import Domain
import Infrastructure

/// Menu Bar pane: what ClaudeBar shows in the macOS status bar.
/// Ports the popover's "Quota Display" card logic unchanged.
struct MenuBarPane: View {
    let monitor: QuotaMonitor

    @Environment(\.appTheme) private var theme
    @State private var settings = AppSettings.shared

    private var menuBarProviders: [any AIProvider] {
        monitor.enabledProviders
    }

    private var selectedMenuBarProvider: (any AIProvider)? {
        menuBarProviders.first { $0.id == settings.menuBarPercentageProviderId }
            ?? monitor.selectedProvider
            ?? menuBarProviders.first
    }

    private var menuBarQuotaOptions: [UsageQuota] {
        selectedMenuBarProvider?.snapshot?.quotas ?? []
    }

    /// Quota options offered for the optional secondary menu bar window,
    /// excluding the one already chosen as primary.
    private var secondaryMenuBarQuotaOptions: [UsageQuota] {
        menuBarQuotaOptions.filter {
            $0.quotaType.quotaKey != settings.menuBarPercentageQuotaKey
        }
    }

    var body: some View {
        SettingsPane(
            title: "Menu Bar",
            subtitle: "What ClaudeBar shows in the macOS status bar."
        ) {
            SettingsCard {
                SettingsFieldLabel(text: "QUOTA DISPLAY")
                    .padding(.bottom, 8)

                HStack(spacing: 8) {
                    ForEach(UsageDisplayMode.allCases, id: \.rawValue) { mode in
                        DisplayModeButton(
                            mode: mode,
                            isSelected: settings.usageDisplayMode == mode
                        ) {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                settings.usageDisplayMode = mode
                            }
                        }
                    }
                }
            }

            SettingsCard {
                SettingsRow(
                    title: "Show Percentage in Menu Bar",
                    subtitle: "A live quota readout beside the status icon."
                ) {
                    SettingsSwitch(isOn: Binding(
                        get: { settings.menuBarPercentageEnabled },
                        set: { enabled in
                            settings.menuBarPercentageEnabled = enabled
                            if enabled {
                                normalizeMenuBarSelection()
                            }
                        }
                    ))
                }

                SettingsRowDivider()

                SettingsRow(
                    title: "Show Duration in Menu Bar",
                    subtitle: "Time until the tracked quota window resets."
                ) {
                    SettingsSwitch(isOn: Binding(
                        get: { settings.menuBarDurationEnabled },
                        set: { enabled in
                            settings.menuBarDurationEnabled = enabled
                            if enabled {
                                normalizeMenuBarSelection()
                            }
                        }
                    ))
                }

                if settings.menuBarPercentageEnabled || settings.menuBarDurationEnabled {
                    SettingsRowDivider()
                    menuBarControls
                }
            }
        }
    }

    private var menuBarControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SettingsFieldLabel(text: "PROVIDER")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(menuBarProviders, id: \.id) { provider in
                            MenuBarProviderChoiceButton(
                                providerId: provider.id,
                                providerName: provider.name,
                                isSelected: settings.menuBarPercentageProviderId == provider.id
                            ) {
                                settings.menuBarPercentageProviderId = provider.id
                                selectFirstMenuBarQuotaIfNeeded(force: true)
                                normalizeSecondaryMenuBarSelection()
                            }
                        }
                    }
                }
                .disabled(menuBarProviders.isEmpty)
            }

            VStack(alignment: .leading, spacing: 6) {
                SettingsFieldLabel(text: "QUOTA")

                if menuBarQuotaOptions.isEmpty {
                    Text("No quota data")
                        .font(.system(size: 11, weight: .medium, design: theme.fontDesign))
                        .foregroundStyle(theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(
                            RoundedRectangle(cornerRadius: theme.pillCornerRadius)
                                .fill(theme.glassBackground)
                                .overlay(
                                    RoundedRectangle(cornerRadius: theme.pillCornerRadius)
                                        .stroke(theme.glassBorder, lineWidth: 1)
                                )
                        )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(menuBarQuotaOptions, id: \.quotaType.quotaKey) { quota in
                                MenuBarQuotaChoiceButton(
                                    title: quota.menuBarTitle ?? quota.quotaType.displayName,
                                    isSelected: settings.menuBarPercentageQuotaKey == quota.quotaType.quotaKey
                                ) {
                                    settings.menuBarPercentageQuotaKey = quota.quotaType.quotaKey
                                    normalizeSecondaryMenuBarSelection()
                                }
                            }
                        }
                    }
                }
            }

            if menuBarQuotaOptions.count > 1 {
                VStack(alignment: .leading, spacing: 6) {
                    SettingsFieldLabel(text: "SECONDARY QUOTA")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            MenuBarChoiceButton(
                                iconName: "minus.circle",
                                label: "None",
                                isSelected: settings.menuBarSecondaryQuotaKey.isEmpty
                            ) {
                                settings.menuBarSecondaryQuotaKey = ""
                            }

                            ForEach(secondaryMenuBarQuotaOptions, id: \.quotaType.quotaKey) { quota in
                                MenuBarQuotaChoiceButton(
                                    title: quota.menuBarTitle ?? quota.quotaType.displayName,
                                    isSelected: settings.menuBarSecondaryQuotaKey == quota.quotaType.quotaKey
                                ) {
                                    settings.menuBarSecondaryQuotaKey = quota.quotaType.quotaKey
                                }
                            }
                        }
                    }

                    // Stacking only changes how two windows render, so the
                    // toggle appears once a secondary window is selected.
                    if !settings.menuBarSecondaryQuotaKey.isEmpty {
                        SettingsRow(
                            title: "Stack in Menu Bar",
                            subtitle: "Draw the two windows as two smaller lines, halving the width."
                        ) {
                            SettingsSwitch(isOn: Binding(
                                get: { settings.menuBarStackedEnabled },
                                set: { settings.menuBarStackedEnabled = $0 }
                            ))
                        }
                        .padding(.top, 6)

                        // The size only matters while stacking is actually
                        // rendering, so it appears with the toggle on.
                        if settings.menuBarStackedEnabled {
                            VStack(alignment: .leading, spacing: 6) {
                                SettingsFieldLabel(text: "STACKED TEXT SIZE")

                                HStack(spacing: 8) {
                                    ForEach(MenuBarStackedSize.allCases, id: \.self) { size in
                                        MenuBarChoiceButton(
                                            iconName: size.choiceIconName,
                                            label: size.displayLabel,
                                            isSelected: settings.menuBarStackedSize == size
                                        ) {
                                            settings.menuBarStackedSize = size
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        .onAppear {
            normalizeMenuBarSelection()
            normalizeSecondaryMenuBarSelection()
        }
    }

    /// Clears a stored secondary quota key that is no longer offered — e.g. after it
    /// becomes equal to the primary, or the chosen provider's quotas no longer include it.
    private func normalizeSecondaryMenuBarSelection() {
        guard !settings.menuBarSecondaryQuotaKey.isEmpty else { return }
        // An empty options list means quota data has not loaded yet (cold
        // start, provider still syncing), not that the stored selection is
        // invalid. Clearing here would silently discard the user's secondary
        // window on any settings interaction during a sync.
        let validKeys = Set(secondaryMenuBarQuotaOptions.map(\.quotaType.quotaKey))
        guard !validKeys.isEmpty else { return }
        if !validKeys.contains(settings.menuBarSecondaryQuotaKey) {
            settings.menuBarSecondaryQuotaKey = ""
        }
    }

    private func normalizeMenuBarSelection() {
        if let provider = selectedMenuBarProvider,
           settings.menuBarPercentageProviderId != provider.id {
            settings.menuBarPercentageProviderId = provider.id
        }
        selectFirstMenuBarQuotaIfNeeded(force: false)
    }

    private func selectFirstMenuBarQuotaIfNeeded(force: Bool) {
        if let firstQuota = menuBarQuotaOptions.first {
            let currentQuotaExists = menuBarQuotaOptions.contains {
                $0.quotaType.quotaKey == settings.menuBarPercentageQuotaKey
            }

            if force || !currentQuotaExists {
                settings.menuBarPercentageQuotaKey = firstQuota.quotaType.quotaKey
            }
        } else if force {
            settings.menuBarPercentageQuotaKey = "session"
        }
    }
}
