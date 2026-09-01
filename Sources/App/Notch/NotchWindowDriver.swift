import AppKit
import Domain
import Infrastructure

/// Keeps the notch in sync with the app's state.
///
/// Mirrors `StatusItemLabelDriver`: an `ObservationRenderSync` reads every
/// `@Observable` property the notch depends on and pushes the resolved activity
/// into the window controller. SwiftUI is not involved — the notch lives in its
/// own `NSPanel`, and `MenuBarExtra`'s hosting has a history of going quiet
/// after sleep (issue #192).
@MainActor
final class NotchWindowDriver {
    private let monitor: QuotaMonitor
    private let sessionMonitor: SessionMonitor
    private let settings: AppSettings
    private let controller = NotchWindowController()
    private let resolver = NotchActivityResolver()

    private var activitySync: ObservationRenderSync<NotchActivity?>?
    private var enabledSync: ObservationRenderSync<Bool>?

    /// Retracts the "done" flash, which expires on a clock rather than on state.
    private var expiryTimer: Timer?

    init(monitor: QuotaMonitor, sessionMonitor: SessionMonitor, settings: AppSettings) {
        self.monitor = monitor
        self.sessionMonitor = sessionMonitor
        self.settings = settings
    }

    /// Starts watching the setting, bringing the notch up and down with it.
    func start() {
        let sync = ObservationRenderSync<Bool>(
            read: { [settings] in settings.notchEnabled },
            render: { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    controller.start()
                    startActivitySync()
                } else {
                    stopActivitySync()
                    controller.stop()
                }
            }
        )
        enabledSync = sync
        sync.start()
    }

    // MARK: - Private

    private func startActivitySync() {
        guard activitySync == nil else { return }

        let sync = ObservationRenderSync<NotchActivity?>(
            read: { [weak self] in self?.currentActivity() ?? nil },
            render: { [weak self] activity in
                self?.controller.update(activity: activity)
                self?.scheduleExpiry(for: activity)
            }
        )
        activitySync = sync
        sync.start()
    }

    private func stopActivitySync() {
        activitySync?.stop()
        activitySync = nil
        expiryTimer?.invalidate()
        expiryTimer = nil
    }

    /// Reads everything the notch depends on. Every `@Observable` property
    /// touched here is tracked, so any change re-resolves the activity.
    private func currentActivity() -> NotchActivity? {
        let sessions = [sessionMonitor.activeSession].compactMap { $0 }
            + sessionMonitor.recentSessions
        let quotas = monitor.enabledProviders.compactMap(\.snapshot).flatMap(\.quotas)

        return resolver.resolve(sessions: sessions, quotas: quotas, now: Date())
    }

    /// A finished session stops being worth showing on a clock, not on a state
    /// change — nothing will fire an observation to retract it, so schedule the
    /// re-resolve ourselves.
    private func scheduleExpiry(for activity: NotchActivity?) {
        expiryTimer?.invalidate()
        expiryTimer = nil

        guard case .finished(let session) = activity, let finishedAt = session.finishedAt else { return }

        let remaining = NotchActivityResolver.defaultFinishedDisplayDuration
            - Date().timeIntervalSince(finishedAt)
        guard remaining > 0 else { return }

        expiryTimer = Timer.scheduledTimer(withTimeInterval: remaining + 0.1, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.activitySync?.refreshNow()
            }
        }
    }
}
