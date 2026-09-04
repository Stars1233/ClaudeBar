import Testing
import Foundation
@testable import Domain

@Suite
struct NotifyPublishGateTests {
    /// Fixed on purpose: every rule below is exercised against an explicit
    /// elapsed time rather than against the machine's clock.
    private let now = Date(timeIntervalSince1970: 1_700_000_000)

    /// The shipping intervals, spelled out so a test reads as "thirty seconds
    /// is inside the minute" without a lookup elsewhere.
    private let gate = NotifyPublishGate(tileInterval: 60, gaugeInterval: 900, keepAliveInterval: 5400)

    /// A payload with either surface present. A nil argument means the user
    /// turned that surface off.
    private func payload(tile body: String?, gauge value: String?) -> NotifyPayload {
        NotifyPayload(
            tile: body.flatMap { NotifyTile(title: "ClaudeBar", body: $0, progress: 42) },
            gauge: value.flatMap { NotifyGauge(title: "ClaudeBar", value: $0, progress: 42) }
        )
    }

    // MARK: - The first publish

    @Test
    func `a first publish writes both surfaces`() {
        let decision = gate.decide(payload: payload(tile: "42% left", gauge: "42"), since: nil, now: now)

        #expect(decision.publishesTile)
        #expect(decision.publishesGauge)
    }

    // MARK: - Nothing changed

    @Test
    func `an unchanged payload republishes nothing before the keep alive elapses`() {
        // Given the same payload as an hour ago
        let standing = payload(tile: "42% left", gauge: "42")
        let record = NotifyPublishRecord(payload: standing, tileAt: now, gaugeAt: now)

        // When
        let decision = gate.decide(payload: standing, since: record, now: now.addingTimeInterval(3600))

        // Then no request is worth making
        #expect(decision.publishesNothing)
    }

    // MARK: - The tile

    @Test
    func `a changed tile waits for the tile interval`() {
        let record = NotifyPublishRecord(payload: payload(tile: "42% left", gauge: "42"), tileAt: now, gaugeAt: now)

        let decision = gate.decide(
            payload: payload(tile: "41% left", gauge: "42"),
            since: record,
            now: now.addingTimeInterval(30)
        )

        #expect(!decision.publishesTile)
    }

    @Test
    func `a changed tile publishes once the tile interval has passed`() {
        let record = NotifyPublishRecord(payload: payload(tile: "42% left", gauge: "42"), tileAt: now, gaugeAt: now)

        let decision = gate.decide(
            payload: payload(tile: "41% left", gauge: "42"),
            since: record,
            now: now.addingTimeInterval(60)
        )

        #expect(decision.publishesTile)
    }

    @Test
    func `an unchanged tile publishes again once the keep alive interval has passed`() {
        // The gateway ends a progress-only Live Activity that has gone two
        // hours without an update, so a frozen percentage has to be refreshed
        // even when it has not moved.
        let standing = payload(tile: "42% left", gauge: "42")
        let record = NotifyPublishRecord(payload: standing, tileAt: now, gaugeAt: now)

        let decision = gate.decide(payload: standing, since: record, now: now.addingTimeInterval(5400))

        #expect(decision.publishesTile)
    }

    // MARK: - The gauge

    @Test
    func `a changed gauge waits for the gauge interval`() {
        let record = NotifyPublishRecord(payload: payload(tile: "42% left", gauge: "42"), tileAt: now, gaugeAt: now)

        let decision = gate.decide(
            payload: payload(tile: "42% left", gauge: "41"),
            since: record,
            now: now.addingTimeInterval(300)
        )

        #expect(!decision.publishesGauge)
    }

    @Test
    func `a changed gauge publishes once the gauge interval has passed`() {
        let record = NotifyPublishRecord(payload: payload(tile: "42% left", gauge: "42"), tileAt: now, gaugeAt: now)

        let decision = gate.decide(
            payload: payload(tile: "42% left", gauge: "41"),
            since: record,
            now: now.addingTimeInterval(900)
        )

        #expect(decision.publishesGauge)
    }

    @Test
    func `the keep alive does not force a gauge publish`() {
        // The keep alive exists for the Live Activity reaper. A widget iOS
        // already redraws on its own schedule gains nothing from it.
        let standing = payload(tile: "42% left", gauge: "42")
        let record = NotifyPublishRecord(payload: standing, tileAt: now, gaugeAt: now)

        let decision = gate.decide(payload: standing, since: record, now: now.addingTimeInterval(5400))

        #expect(!decision.publishesGauge)
    }

    // MARK: - Surfaces the user turned off

    @Test
    func `a payload with no tile never publishes a tile`() {
        let decision = gate.decide(payload: payload(tile: nil, gauge: "42"), since: nil, now: now)

        #expect(!decision.publishesTile)
        #expect(decision.publishesGauge)
    }

    @Test
    func `a payload with no gauge never publishes a gauge`() {
        let decision = gate.decide(payload: payload(tile: "42% left", gauge: nil), since: nil, now: now)

        #expect(!decision.publishesGauge)
        #expect(decision.publishesTile)
    }

    // MARK: - The record

    @Test
    func `a publish record carries forward the timestamp of the surface it did not write`() {
        // Given both surfaces last written at the same moment
        let record = NotifyPublishRecord(payload: payload(tile: "42% left", gauge: "42"), tileAt: now, gaugeAt: now)
        let next = payload(tile: "41% left", gauge: "41")

        // When only the tile goes out, two minutes later
        let updated = record.updated(
            with: next,
            decision: NotifyPublishDecision(publishesTile: true, publishesGauge: false),
            at: now.addingTimeInterval(120)
        )

        // Then the gauge keeps its old timestamp, so its own interval still applies
        #expect(updated.payload == next)
        #expect(updated.tileAt == now.addingTimeInterval(120))
        #expect(updated.gaugeAt == now)
    }

    // MARK: - The decision

    @Test
    func `a decision that writes nothing reports publishing nothing`() {
        #expect(NotifyPublishDecision.nothing.publishesNothing)
        #expect(!NotifyPublishDecision.nothing.publishesTile)
        #expect(!NotifyPublishDecision.nothing.publishesGauge)
        #expect(NotifyPublishDecision(publishesTile: false, publishesGauge: false) == .nothing)
    }

    @Test
    func `a decision that writes one surface does not report publishing nothing`() {
        #expect(!NotifyPublishDecision(publishesTile: true, publishesGauge: false).publishesNothing)
        #expect(!NotifyPublishDecision(publishesTile: false, publishesGauge: true).publishesNothing)
    }
}
