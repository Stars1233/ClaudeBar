import Foundation

/// What the last publish sent, and when each surface was last written.
public struct NotifyPublishRecord: Sendable, Equatable {
    public let payload: NotifyPayload
    public let tileAt: Date?
    public let gaugeAt: Date?

    public init(payload: NotifyPayload, tileAt: Date? = nil, gaugeAt: Date? = nil) {
        self.payload = payload
        self.tileAt = tileAt
        self.gaugeAt = gaugeAt
    }

    /// The record after a publish, carrying forward the timestamp of whichever
    /// surface was not written this time.
    public func updated(with payload: NotifyPayload, decision: NotifyPublishDecision, at now: Date) -> NotifyPublishRecord {
        NotifyPublishRecord(
            payload: payload,
            tileAt: decision.publishesTile ? now : tileAt,
            gaugeAt: decision.publishesGauge ? now : gaugeAt
        )
    }
}

/// Which surfaces a publish should actually write.
public struct NotifyPublishDecision: Sendable, Equatable {
    public let publishesTile: Bool
    public let publishesGauge: Bool

    public init(publishesTile: Bool, publishesGauge: Bool) {
        self.publishesTile = publishesTile
        self.publishesGauge = publishesGauge
    }

    public var publishesNothing: Bool {
        !publishesTile && !publishesGauge
    }

    public static let nothing = NotifyPublishDecision(publishesTile: false, publishesGauge: false)
}

/// Decides when a payload is worth a request.
///
/// Quota numbers move on every refresh, and the reset countdown in the detail
/// line moves every minute, so "publish whenever the payload differs" would
/// mean a request per refresh forever. The gate adds two rules on top of that
/// difference:
///
/// - a minimum gap per surface, because iOS redraws a widget roughly every
///   fifteen minutes no matter how often the value is pushed, so pushing faster
///   buys nothing;
/// - a keep alive for the tile, because the gateway ends a progress-only Live
///   Activity that has gone two hours without an update, on the grounds that a
///   frozen percentage is worse than no tile at all. Republishing every ninety
///   minutes keeps it alive with room to spare.
///
/// Pure and clock free: `now` is a parameter, so every rule is directly testable.
public struct NotifyPublishGate: Sendable {
    /// The tile is a push, so it can afford to be prompt.
    public static let defaultTileInterval: TimeInterval = 60

    /// The widget is a poll. iOS decides when it redraws, roughly every quarter
    /// hour, so there is nothing to gain from writing it more often.
    public static let defaultGaugeInterval: TimeInterval = 15 * 60

    /// Comfortably inside the gateway's two hour abandonment reaper.
    public static let defaultKeepAliveInterval: TimeInterval = 90 * 60

    private let tileInterval: TimeInterval
    private let gaugeInterval: TimeInterval
    private let keepAliveInterval: TimeInterval

    public init(
        tileInterval: TimeInterval = NotifyPublishGate.defaultTileInterval,
        gaugeInterval: TimeInterval = NotifyPublishGate.defaultGaugeInterval,
        keepAliveInterval: TimeInterval = NotifyPublishGate.defaultKeepAliveInterval
    ) {
        self.tileInterval = tileInterval
        self.gaugeInterval = gaugeInterval
        self.keepAliveInterval = keepAliveInterval
    }

    public func decide(
        payload: NotifyPayload,
        since record: NotifyPublishRecord?,
        now: Date
    ) -> NotifyPublishDecision {
        NotifyPublishDecision(
            publishesTile: publishesTile(payload: payload, record: record, now: now),
            publishesGauge: publishesGauge(payload: payload, record: record, now: now)
        )
    }

    private func publishesTile(payload: NotifyPayload, record: NotifyPublishRecord?, now: Date) -> Bool {
        guard let tile = payload.tile else { return false }
        guard let record, let lastAt = record.tileAt else { return true }

        let elapsed = now.timeIntervalSince(lastAt)
        if elapsed >= keepAliveInterval { return true }
        return tile != record.payload.tile && elapsed >= tileInterval
    }

    private func publishesGauge(payload: NotifyPayload, record: NotifyPublishRecord?, now: Date) -> Bool {
        guard let gauge = payload.gauge else { return false }
        guard let record, let lastAt = record.gaugeAt else { return true }

        let elapsed = now.timeIntervalSince(lastAt)
        return gauge != record.payload.gauge && elapsed >= gaugeInterval
    }
}
