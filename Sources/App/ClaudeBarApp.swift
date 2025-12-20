import SwiftUI
import Domain
import Infrastructure

/// Shared app state observable by all views
@Observable
final class AppState {
    /// Current snapshots by provider
    var snapshots: [AIProvider: UsageSnapshot] = [:]

    /// The overall status across all providers
    var overallStatus: QuotaStatus {
        snapshots.values.map(\.overallStatus).max() ?? .healthy
    }

    /// Whether a refresh is in progress
    var isRefreshing: Bool = false

    /// Last error message, if any
    var lastError: String?
}

@main
struct ClaudeBarApp: App {
    /// The main domain service - monitors all AI providers
    @State private var monitor: QuotaMonitor

    /// Shared app state
    @State private var appState = AppState()

    /// Notification observer
    private let notificationObserver = NotificationQuotaObserver()

    init() {
        // Create probes for each provider
        let probes: [any UsageProbePort] = [
            ClaudeUsageProbe(),
            CodexUsageProbe(),
            GeminiUsageProbe(),
        ]

        // Initialize the domain service with notification observer
        _monitor = State(initialValue: QuotaMonitor(
            probes: probes,
            observer: notificationObserver
        ))

        // Request notification permission
        let observer = notificationObserver
        Task {
            _ = await observer.requestPermission()
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(monitor: monitor, appState: appState)
        } label: {
            StatusBarIcon(status: appState.overallStatus)
        }
        .menuBarExtraStyle(.window)
    }
}

/// The menu bar icon that reflects the overall quota status
struct StatusBarIcon: View {
    let status: QuotaStatus

    var body: some View {
        Image(systemName: iconName)
            .foregroundStyle(status.displayColor)
    }

    private var iconName: String {
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
}
