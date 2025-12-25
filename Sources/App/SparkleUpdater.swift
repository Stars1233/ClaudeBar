#if ENABLE_SPARKLE
import Sparkle
import SwiftUI
import UserNotifications

/// Delegate that implements gentle reminders for menu bar apps.
/// This allows showing a subtle indicator when an update is available.
@MainActor
final class SparkleUserDriverDelegate: NSObject, SPUStandardUserDriverDelegate {
    /// Callback when update status changes
    var onUpdateAvailable: (@MainActor (Bool) -> Void)?

    /// Declare support for gentle scheduled update reminders
    nonisolated var supportsGentleScheduledUpdateReminders: Bool {
        true
    }

    /// Called when Sparkle is about to show an update
    /// We use this to show a gentle reminder instead of intrusive UI
    nonisolated func standardUserDriverWillHandleShowingUpdate(
        _ handleShowingUpdate: Bool,
        forUpdate update: SUAppcastItem,
        state: SPUUserUpdateState
    ) {
        let version = update.displayVersionString

        // Post a user notification for gentle reminder
        let content = UNMutableNotificationContent()
        content.title = "Update Available"
        content.body = "ClaudeBar \(version) is available. Click to update."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "sparkle-update",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)

        // Notify on main actor
        Task { @MainActor [weak self] in
            self?.onUpdateAvailable?(true)
        }
    }

    /// Called when user interacts with the update
    nonisolated func standardUserDriverDidReceiveUserAttention(forUpdate update: SUAppcastItem) {
        Task { @MainActor [weak self] in
            self?.onUpdateAvailable?(false)
        }
    }

    /// Called when the update session finishes
    nonisolated func standardUserDriverWillFinishUpdateSession() {
        // Remove any pending notifications
        UNUserNotificationCenter.current().removeDeliveredNotifications(
            withIdentifiers: ["sparkle-update"]
        )

        Task { @MainActor [weak self] in
            self?.onUpdateAvailable?(false)
        }
    }
}

/// A wrapper around SPUUpdater for SwiftUI integration.
/// This class manages the Sparkle update lifecycle and provides
/// observable properties for UI binding.
@MainActor
@Observable
final class SparkleUpdater {
    /// The underlying Sparkle updater controller (nil if bundle is invalid)
    private var controller: SPUStandardUpdaterController?

    /// The user driver delegate for gentle reminders
    private var userDriverDelegate: SparkleUserDriverDelegate?

    /// Whether an update check is currently in progress
    private(set) var isCheckingForUpdates = false

    /// Whether an update is available (for showing badge)
    private(set) var updateAvailable = false

    /// Whether the updater is available (bundle is properly configured)
    var isAvailable: Bool {
        controller != nil
    }

    /// Whether updates can be checked (updater is configured and ready)
    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }

    /// The date of the last update check
    var lastUpdateCheckDate: Date? {
        controller?.updater.lastUpdateCheckDate
    }

    /// Whether automatic update checks are enabled
    var automaticallyChecksForUpdates: Bool {
        get { controller?.updater.automaticallyChecksForUpdates ?? false }
        set { controller?.updater.automaticallyChecksForUpdates = newValue }
    }

    init() {
        // Check if we're in a proper app bundle
        if Self.isProperAppBundle() {
            // Create delegate for gentle reminders
            let delegate = SparkleUserDriverDelegate()
            delegate.onUpdateAvailable = { [weak self] available in
                self?.updateAvailable = available
            }
            userDriverDelegate = delegate

            // Normal app bundle - initialize Sparkle with delegate
            controller = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: delegate
            )
        } else {
            // Debug/development build - Sparkle won't work without proper bundle
            print("SparkleUpdater: Not running from app bundle, updater disabled")
        }
    }

    /// Manually check for updates
    func checkForUpdates() {
        guard let controller = controller, controller.updater.canCheckForUpdates else {
            return
        }
        controller.checkForUpdates(nil)
    }

    /// Check for updates in the background (no UI unless update found)
    func checkForUpdatesInBackground() {
        controller?.updater.checkForUpdatesInBackground()
    }

    /// Check if running from a proper .app bundle
    private static func isProperAppBundle() -> Bool {
        let bundle = Bundle.main

        // Check bundle path ends with .app
        guard bundle.bundlePath.hasSuffix(".app") else {
            return false
        }

        // Check required keys exist
        guard let info = bundle.infoDictionary,
              info["CFBundleIdentifier"] != nil,
              info["CFBundleVersion"] != nil,
              info["SUFeedURL"] != nil else {
            return false
        }

        return true
    }
}

// MARK: - SwiftUI Environment

/// Environment key for accessing the SparkleUpdater
private struct SparkleUpdaterKey: EnvironmentKey {
    static let defaultValue: SparkleUpdater? = nil
}

extension EnvironmentValues {
    @MainActor
    var sparkleUpdater: SparkleUpdater? {
        get { self[SparkleUpdaterKey.self] }
        set { self[SparkleUpdaterKey.self] = newValue }
    }
}
#endif
