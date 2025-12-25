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
        guard !providers.contains(where: { $0.id == provider.id }) else { return }
        providers.append(provider)
        AIProviderRegistry.shared.register([provider])
    }

    /// Removes a provider by ID
    func removeProvider(id: String) {
        providers.removeAll { $0.id == id }
    }
}

@main
struct ClaudeBarApp: App {
    /// The main domain service - monitors all AI providers
    @State private var monitor: QuotaMonitor

    /// Shared app state
    @State private var appState = AppState()

    /// Notification observer
    private let notificationObserver = NotificationQuotaObserver()

    #if ENABLE_SPARKLE
    /// Sparkle updater for auto-updates
    @State private var sparkleUpdater = SparkleUpdater()
    #endif

    init() {
        // Create providers with their probes (rich domain models)
        var providers: [any AIProvider] = [
            ClaudeProvider(probe: ClaudeUsageProbe()),
            CodexProvider(probe: CodexUsageProbe()),
            GeminiProvider(probe: GeminiUsageProbe()),
        ]

        // Add Copilot provider if configured
        if AppSettings.shared.copilotEnabled && AppSettings.shared.hasCopilotToken {
            providers.append(CopilotProvider(probe: CopilotUsageProbe()))
        }

        // Register providers for global access
        AIProviderRegistry.shared.register(providers)

        // Store providers in app state
        appState = AppState(providers: providers)

        // Initialize the domain service with notification observer
        monitor = QuotaMonitor(
            providers: providers,
            statusObserver: notificationObserver
        )

        // Request notification permission
        let observer = notificationObserver
        Task {
            _ = await observer.requestPermission()
        }
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
            MenuContentView(monitor: monitor, appState: appState)
                .themeProvider(currentThemeMode)
                .environment(\.sparkleUpdater, sparkleUpdater)
            #else
            MenuContentView(monitor: monitor, appState: appState)
                .themeProvider(currentThemeMode)
            #endif
        } label: {
            #if ENABLE_SPARKLE
            StatusBarIcon(
                status: appState.overallStatus,
                isChristmas: currentThemeMode == .christmas,
                hasUpdate: sparkleUpdater.updateAvailable
            )
            #else
            StatusBarIcon(status: appState.overallStatus, isChristmas: currentThemeMode == .christmas)
            #endif
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon that reflects the overall quota status
struct StatusBarIcon: View {
    let status: QuotaStatus
    var isChristmas: Bool = false
    var hasUpdate: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: iconName)
                .foregroundStyle(iconColor)

            // Show update badge as a small dot
            if hasUpdate {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 6, height: 6)
                    .offset(x: 2, y: -2)
            }
        }
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
