import Foundation

/// Events emitted during continuous monitoring
public enum MonitoringEvent: Sendable {
    /// A refresh cycle completed
    case refreshed
    /// An error occurred during refresh for a provider
    case error(providerId: String, Error)
}

/// The main domain service that coordinates quota monitoring across AI providers.
/// Providers are rich domain models that own their own snapshots.
/// QuotaMonitor coordinates refreshes and optionally notifies a status handler.
public actor QuotaMonitor {
    /// All registered providers
    private let providers: [any AIProvider]

    /// Optional listener for status changes (e.g., QuotaAlerter)
    private let statusListener: (any QuotaStatusListener)?

    /// Previous status for change detection
    private var previousStatuses: [String: QuotaStatus] = [:]

    /// Current monitoring task
    private var monitoringTask: Task<Void, Never>?

    /// Whether monitoring is active
    public private(set) var isMonitoring: Bool = false

    // MARK: - Initialization

    public init(
        providers: [any AIProvider],
        statusListener: (any QuotaStatusListener)? = nil
    ) {
        self.providers = providers
        self.statusListener = statusListener
    }

    // MARK: - Monitoring Operations

    /// Refreshes all registered providers concurrently.
    /// Each provider updates its own snapshot.
    public func refreshAll() async {
        await withTaskGroup(of: Void.self) { group in
            for provider in providers {
                group.addTask {
                    await self.refreshProvider(provider)
                }
            }
        }
    }

    /// Refreshes a single provider
    private func refreshProvider(_ provider: any AIProvider) async {
        guard await provider.isAvailable() else {
            return
        }

        do {
            let snapshot = try await provider.refresh()
            await handleSnapshotUpdate(provider: provider, snapshot: snapshot)
        } catch {
            // Provider stores error in lastError - no need for external observer
        }
    }

    /// Handles snapshot update and notifies status observer if status changed
    private func handleSnapshotUpdate(provider: any AIProvider, snapshot: UsageSnapshot) async {
        let previousStatus = previousStatuses[provider.id] ?? .healthy
        let newStatus = snapshot.overallStatus

        previousStatuses[provider.id] = newStatus

        // Notify listener only if status changed
        if previousStatus != newStatus, let listener = statusListener {
            await listener.onStatusChanged(
                providerId: provider.id,
                oldStatus: previousStatus,
                newStatus: newStatus
            )
        }
    }

    /// Refreshes a single provider by its ID.
    public func refresh(providerId: String) async {
        guard let provider = providers.first(where: { $0.id == providerId }) else {
            return
        }
        await refreshProvider(provider)
    }

    /// Refreshes all providers except the specified one.
    public func refreshOthers(except providerId: String) async {
        let otherProviders = providers.filter { $0.id != providerId }

        await withTaskGroup(of: Void.self) { group in
            for provider in otherProviders {
                group.addTask {
                    await self.refreshProvider(provider)
                }
            }
        }
    }

    // MARK: - Queries

    /// Returns the provider with the given ID
    public func provider(for id: String) -> (any AIProvider)? {
        providers.first { $0.id == id }
    }

    /// Returns all providers
    public var allProviders: [any AIProvider] {
        providers
    }

    /// Returns the lowest quota across all monitored providers
    public func lowestQuota() -> UsageQuota? {
        providers
            .compactMap(\.snapshot?.lowestQuota)
            .min()
    }

    /// Returns the overall status across all providers (worst status wins)
    public func overallStatus() -> QuotaStatus {
        providers
            .compactMap(\.snapshot?.overallStatus)
            .max() ?? .healthy
    }

    // MARK: - Continuous Monitoring

    /// Starts continuous monitoring at the specified interval.
    /// Returns an AsyncStream of monitoring events.
    public func startMonitoring(interval: Duration = .seconds(60)) -> AsyncStream<MonitoringEvent> {
        // Stop any existing monitoring
        monitoringTask?.cancel()

        isMonitoring = true

        return AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    await self.refreshAll()
                    continuation.yield(.refreshed)

                    do {
                        try await Task.sleep(for: interval)
                    } catch {
                        break
                    }
                }
                continuation.finish()
            }

            self.monitoringTask = task

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Stops continuous monitoring
    public func stopMonitoring() {
        isMonitoring = false
        monitoringTask?.cancel()
        monitoringTask = nil
    }
}
