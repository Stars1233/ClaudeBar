import Foundation

/// Defaults for the Notify! integration.
public enum NotifyConstants {
    /// Off until the user links a device. The feature sends data to a third
    /// party service, so it can never be on by default.
    public static let defaultEnabled = false

    /// Both surfaces are on once the feature itself is on: a user who linked a
    /// device wants to see their quota, and each can be switched off separately.
    public static let defaultLiveActivityEnabled = true
    public static let defaultWidgetEnabled = true
}

/// Settings for publishing quota state to a Notify! device.
///
/// Standalone protocol rather than a `ProviderSettingsRepository` sub-protocol:
/// Notify! is not a provider ClaudeBar reads a quota from, it is a destination
/// ClaudeBar writes to, so none of the provider vocabulary (enable in the
/// popover, custom card URL, probe mode) applies. Mirrors
/// `HookSettingsRepository`, the other feature that is a peer of the providers
/// rather than one of them.
///
/// The device token is a secret and goes to the Keychain-backed credential
/// store, never to `~/.claudebar/settings.json`.
public protocol NotifySettingsRepository: Sendable {
    /// Whether ClaudeBar publishes to Notify! at all.
    func isNotifyEnabled() -> Bool
    func setNotifyEnabled(_ enabled: Bool)

    /// The linked device id, empty when nothing is linked.
    func notifyDeviceId() -> String
    func setNotifyDeviceId(_ deviceId: String)

    /// The per device token, held in the secure credential store when the
    /// platform will take it.
    func saveNotifyDeviceToken(_ token: String)
    func notifyDeviceToken() -> String?
    @discardableResult
    func deleteNotifyDeviceToken() -> Bool
    func hasNotifyDeviceToken() -> Bool

    /// Whether the stored token is in the Keychain rather than the fallback
    /// store.
    ///
    /// The Keychain refuses an ad-hoc signed build, which is every build made
    /// locally, so a token can legitimately end up in the app credential store
    /// instead. The pane asks so that it can say where the token actually is,
    /// rather than showing a badge that implies the stronger answer.
    func notifyDeviceTokenIsSecure() -> Bool

    /// Whether the Lock Screen Live Activity is published.
    func isNotifyLiveActivityEnabled() -> Bool
    func setNotifyLiveActivityEnabled(_ enabled: Bool)

    /// Whether the Lock Screen widget gauge is published.
    func isNotifyWidgetEnabled() -> Bool
    func setNotifyWidgetEnabled(_ enabled: Bool)

    /// Which provider the widget gauge shows. Empty means "whichever quota
    /// needs attention most".
    func notifyGaugeProviderId() -> String
    func setNotifyGaugeProviderId(_ providerId: String)

    /// Which quota window the widget gauge shows. Empty means automatic.
    func notifyGaugeQuotaKey() -> String
    func setNotifyGaugeQuotaKey(_ quotaKey: String)

    /// The handle of the Live Activity ClaudeBar started, so later updates
    /// address that exact tile and never one the user started elsewhere.
    func notifyActivityId() -> String?
    func setNotifyActivityId(_ activityId: String?)

    /// The handle of the widget ClaudeBar created, for the same reason.
    func notifyWidgetId() -> String?
    func setNotifyWidgetId(_ widgetId: String?)
}

public extension NotifySettingsRepository {
    /// The saved credentials as one value, or nil when either half is missing
    /// or malformed. The single place the rest of the app asks "are we linked".
    func notifyDeviceLink() -> NotifyDeviceLink? {
        guard let token = notifyDeviceToken() else { return nil }
        return NotifyDeviceLink(deviceId: notifyDeviceId(), token: token)
    }

    /// Which quota window the gauge should show.
    func notifyGaugeSelection() -> NotifyGaugeSelection {
        NotifyGaugeSelection(
            providerId: notifyGaugeProviderId(),
            quotaKey: notifyGaugeQuotaKey()
        )
    }
}
