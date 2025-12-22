import Foundation
import UserNotifications
import Domain

/// Infrastructure adapter that sends macOS notifications when quota status changes.
/// Implements QuotaObserverPort from the domain layer.
public final class NotificationQuotaObserver: QuotaObserverPort, @unchecked Sendable {
    /// Lazily initialized notification center to avoid bundle issues during init
    private var notificationCenter: UNUserNotificationCenter? {
        // Only access notification center when running in a proper app context
        guard Bundle.main.bundleIdentifier != nil else { return nil }
        return UNUserNotificationCenter.current()
    }

    public init() {}

    /// Requests notification permission from the user
    public func requestPermission() async -> Bool {
        guard let center = notificationCenter else { return false }
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    // MARK: - QuotaObserverPort

    public func onSnapshotUpdated(_ snapshot: UsageSnapshot) async {
        // No notification needed for regular updates
    }

    public func onStatusChanged(providerId: String, oldStatus: QuotaStatus, newStatus: QuotaStatus) async {
        // Only notify on degradation (getting worse)
        guard newStatus > oldStatus else { return }

        // Skip if status improved or stayed the same
        guard shouldNotify(for: newStatus) else { return }

        let providerName = providerDisplayName(for: providerId)

        let content = UNMutableNotificationContent()
        content.title = "\(providerName) Quota Alert"
        content.body = notificationBody(for: newStatus, providerName: providerName)
        content.sound = .default

        // Add category for actionable notifications
        content.categoryIdentifier = "QUOTA_ALERT"

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil // Deliver immediately
        )

        guard let center = notificationCenter else { return }
        do {
            try await center.add(request)
        } catch {
            // Silently fail - notifications are non-critical
        }
    }

    public func onError(_ error: Error, providerId: String) async {
        // Optionally notify on persistent errors
        guard let probeError = error as? ProbeError else { return }

        let providerName = providerDisplayName(for: providerId)

        // Only notify for authentication issues
        switch probeError {
        case .authenticationRequired:
            let content = UNMutableNotificationContent()
            content.title = "\(providerName) Login Required"
            content.body = "Please log in to \(providerName) to continue monitoring quotas."
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: "auth-\(providerId)",
                content: content,
                trigger: nil
            )

            guard let center = notificationCenter else { return }
            try? await center.add(request)
        default:
            break
        }
    }

    // MARK: - Helpers

    private func shouldNotify(for status: QuotaStatus) -> Bool {
        switch status {
        case .warning, .critical, .depleted:
            return true
        case .healthy:
            return false
        }
    }

    private func providerDisplayName(for providerId: String) -> String {
        switch providerId {
        case "claude": return "Claude"
        case "codex": return "Codex"
        case "gemini": return "Gemini"
        default: return providerId.capitalized
        }
    }

    private func notificationBody(for status: QuotaStatus, providerName: String) -> String {
        switch status {
        case .warning:
            return "Your \(providerName) quota is running low. Consider pacing your usage."
        case .critical:
            return "Your \(providerName) quota is critically low! Save important work."
        case .depleted:
            return "Your \(providerName) quota is depleted. Usage may be blocked."
        case .healthy:
            return "Your \(providerName) quota has recovered."
        }
    }
}
