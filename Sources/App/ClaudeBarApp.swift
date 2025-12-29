import SwiftUI
import Domain
import Infrastructure
#if ENABLE_SPARKLE
import Sparkle
#endif

/// Shared app state observable by all views
@Observable
final class AppState {
    /// The registered providers (rich domain models)
    var providers: [any AIProvider] = []

    /// The overall status across all providers
    var overallStatus: QuotaStatus {
        providers
            .compactMap(\.snapshot?.overallStatus)
            .max() ?? .healthy
    }

    /// Whether any provider is currently refreshing
    var isRefreshing: Bool {
        providers.contains { $0.isSyncing }
    }

    /// Last error message, if any
    var lastError: String?

    init(providers: [any AIProvider] = []) {
        self.providers = providers
    }

    /// Adds a provider if not already present
    func addProvider(_ provider: any AIProvider) {
        guard !providers.contains(where: { $0.id == provider.id }) else {
            AppLog.providers.debug("Provider already exists: \(provider.id)")
            return
        }
        providers.append(provider)
        AIProviderRegistry.shared.register([provider])
        AppLog.providers.info("Added provider: \(provider.id)")
    }

    /// Removes a provider by ID
    func removeProvider(id: String) {
        providers.removeAll { $0.id == id }
        AppLog.providers.info("Removed provider: \(id)")
    }
}

@main
struct ClaudeBarApp: App {
    /// The main domain service - monitors all AI providers
    @State private var monitor: QuotaMonitor

    /// Shared app state
    @State private var appState = AppState()

    /// Alerts users when quota status degrades
    private let quotaAlerter = QuotaAlerter()

    #if ENABLE_SPARKLE
    /// Sparkle updater for auto-updates
    @State private var sparkleUpdater = SparkleUpdater()
    #endif

    init() {
        AppLog.ui.info("ClaudeBar initializing...")
        
        // Create providers with their probes (rich domain models)
        var providers: [any AIProvider] = [
            ClaudeProvider(probe: ClaudeUsageProbe()),
            CodexProvider(probe: CodexUsageProbe()),
            GeminiProvider(probe: GeminiUsageProbe()),
            AntigravityProvider(probe: AntigravityUsageProbe()),
        ]
        AppLog.providers.info("Created base providers: Claude, Codex, Gemini, Antigravity")

        // Add Copilot provider if configured
        if AppSettings.shared.copilotEnabled && AppSettings.shared.hasCopilotToken {
            providers.append(CopilotProvider(probe: CopilotUsageProbe()))
            AppLog.providers.info("Added Copilot provider (enabled and configured)")
        } else if AppSettings.shared.copilotEnabled {
            AppLog.providers.debug("Copilot enabled but no token configured")
        }

        // Register providers for global access
        AIProviderRegistry.shared.register(providers)
        AppLog.providers.info("Registered \(providers.count) providers")

        // Store providers in app state
        appState = AppState(providers: providers)

        // Initialize the domain service with quota alerter
        monitor = QuotaMonitor(
            providers: providers,
            statusListener: quotaAlerter
        )
        AppLog.monitor.info("QuotaMonitor initialized")

        // Note: Notification permission is requested in onAppear, not here
        // Menu bar apps need the run loop to be active before requesting permissions

        AppLog.ui.info("ClaudeBar initialization complete")
    }

    /// App settings for theme
    @State private var settings = AppSettings.shared

    /// Current theme mode from settings
    private var currentThemeMode: ThemeMode {
        ThemeMode(rawValue: settings.themeMode) ?? .system
    }

    var body: some Scene {
        MenuBarExtra {
            #if ENABLE_SPARKLE
            MenuContentView(monitor: monitor, appState: appState, quotaAlerter: quotaAlerter)
                .themeProvider(currentThemeMode)
                .environment(\.sparkleUpdater, sparkleUpdater)
            #else
            MenuContentView(monitor: monitor, appState: appState, quotaAlerter: quotaAlerter)
                .themeProvider(currentThemeMode)
            #endif
        } label: {
            StatusBarIcon(status: appState.overallStatus, isChristmas: currentThemeMode == .christmas)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon that reflects the overall quota status
struct StatusBarIcon: View {
    let status: QuotaStatus
    var isChristmas: Bool = false

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(iconColor)
    }

    private var iconName: String {
        if isChristmas {
            return "snowflake"
        }
        switch status {
        case .depleted:
            return "chart.bar.xaxis"
        case .critical:
            return "exclamationmark.triangle.fill"
        case .warning:
            return "chart.bar.fill"
        case .healthy:
            return "chart.bar.fill"
        }
    }

    private var iconColor: Color {
        if isChristmas {
            return AppTheme.christmasGold
        }
        return status.displayColor
    }
}
