import SwiftUI
import Domain

/// The main menu content view showing all monitored providers.
/// Directly binds to the QuotaMonitor domain service.
struct MenuContentView: View {
    let monitor: QuotaMonitor
    let appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Provider sections
            if appState.snapshots.isEmpty && !appState.isRefreshing {
                emptyStateView
            } else {
                providerListView
            }

            Divider()

            // Footer actions
            footerView
        }
        .frame(width: 320)
        .task {
            await refresh()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.primary)

            Text("ClaudeBar")
                .font(.headline)

            Spacer()

            if appState.isRefreshing {
                ProgressView()
                    .scaleEffect(0.7)
            } else {
                Circle()
                    .fill(appState.overallStatus.displayColor)
                    .frame(width: 10, height: 10)

                Text(overallStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Provider List

    private var providerListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(sortedProviders, id: \.self) { provider in
                    if let snapshot = appState.snapshots[provider] {
                        ProviderSectionView(snapshot: snapshot)

                        if provider != sortedProviders.last {
                            Divider()
                                .padding(.horizontal)
                        }
                    }
                }
            }
        }
        .frame(maxHeight: 400)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.largeTitle)
                .foregroundStyle(.secondary)

            Text("No providers available")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("Install Claude, Codex, or Gemini CLI")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(height: 200)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Button("Refresh") {
                Task {
                    await refresh()
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.blue)

            Spacer()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding()
    }

    // MARK: - Helpers

    private var sortedProviders: [AIProvider] {
        AIProvider.allCases.filter { appState.snapshots[$0] != nil }
    }

    private var overallStatusText: String {
        switch appState.overallStatus {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .critical: return "Critical"
        case .depleted: return "Depleted"
        }
    }

    private func refresh() async {
        appState.isRefreshing = true
        defer { appState.isRefreshing = false }

        do {
            appState.snapshots = try await monitor.refreshAll()
            appState.lastError = nil
        } catch {
            appState.lastError = error.localizedDescription
        }
    }
}
