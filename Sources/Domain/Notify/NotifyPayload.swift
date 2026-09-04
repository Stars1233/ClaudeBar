import Foundation

/// One provider's quota window, paired with the provider's display name.
///
/// The App layer reads these off `QuotaMonitor`; the payload builder needs the
/// name for a metric label and must not reach into `AIProvider`, which is main
/// actor isolated.
public struct NotifyQuotaReading: Sendable, Equatable {
    public let providerId: String
    public let providerName: String
    public let quota: UsageQuota

    public init(providerId: String, providerName: String, quota: UsageQuota) {
        self.providerId = providerId
        self.providerName = providerName
        self.quota = quota
    }
}

/// Which quota the widget gauge shows.
///
/// Both fields empty means "whichever quota needs attention most", which is
/// the useful default for a glance and the only sane behavior before the user
/// has chosen anything.
public struct NotifyGaugeSelection: Sendable, Equatable {
    public let providerId: String
    public let quotaKey: String

    public init(providerId: String = "", quotaKey: String = "") {
        self.providerId = providerId
        self.quotaKey = quotaKey
    }

    /// Whether the selection names a specific window.
    public var isAutomatic: Bool {
        providerId.isEmpty || quotaKey.isEmpty
    }

    public static let automatic = NotifyGaugeSelection()
}

/// Everything ClaudeBar wants standing on the phone right now.
///
/// `Equatable` on purpose: the App driver hands each payload to
/// `ObservationRenderSync`, which drops one identical to the last, so an
/// unchanged quota costs no HTTP at all. A nil surface means the user turned
/// that surface off, and the driver leaves it alone rather than clearing it.
public struct NotifyPayload: Sendable, Equatable {
    public let tile: NotifyTile?
    public let gauge: NotifyGauge?

    public init(tile: NotifyTile? = nil, gauge: NotifyGauge? = nil) {
        self.tile = tile
        self.gauge = gauge
    }

    /// Nothing to say, so nothing to send.
    public var isEmpty: Bool {
        tile == nil && gauge == nil
    }

    public static let empty = NotifyPayload()
}
