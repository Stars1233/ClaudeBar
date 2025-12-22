import Testing
import Foundation
@testable import Domain

/// Mock probe for testing
struct MockProbe: UsageProbe {
    var isAvailableResult: Bool = true
    var probeResult: UsageSnapshot?
    var probeError: Error?

    func probe() async throws -> UsageSnapshot {
        if let error = probeError {
            throw error
        }
        return probeResult ?? UsageSnapshot(
            providerId: "mock",
            quotas: [],
            capturedAt: Date()
        )
    }

    func isAvailable() async -> Bool {
        isAvailableResult
    }
}

@Suite
struct QuotaMonitorTests {

    // MARK: - Single Provider Monitoring

    @Test
    func `monitor can refresh a provider by ID`() async throws {
        // Given
        let probe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [
                UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude"),
                UsageQuota(percentRemaining: 35, quotaType: .weekly, providerId: "claude"),
            ],
            capturedAt: Date()
        ))
        let provider = ClaudeProvider(probe: probe)
        let monitor = QuotaMonitor(providers: [provider])

        // When
        await monitor.refresh(providerId: "claude")

        // Then
        #expect(provider.snapshot != nil)
        #expect(provider.snapshot?.quotas.count == 2)
        #expect(provider.snapshot?.quota(for: .session)?.percentRemaining == 65)
    }

    @Test
    func `monitor skips unavailable providers`() async {
        // Given
        let probe = MockProbe(isAvailableResult: false)
        let provider = ClaudeProvider(probe: probe)
        let monitor = QuotaMonitor(providers: [provider])

        // When
        await monitor.refreshAll()

        // Then
        #expect(provider.snapshot == nil)
    }

    // MARK: - Multiple Provider Monitoring

    @Test
    func `monitor refreshes all providers concurrently`() async {
        // Given
        let claudeProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 70, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        ))
        let codexProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "codex",
            quotas: [UsageQuota(percentRemaining: 40, quotaType: .session, providerId: "codex")],
            capturedAt: Date()
        ))

        let claudeProvider = ClaudeProvider(probe: claudeProbe)
        let codexProvider = CodexProvider(probe: codexProbe)
        let monitor = QuotaMonitor(providers: [claudeProvider, codexProvider])

        // When
        await monitor.refreshAll()

        // Then
        #expect(claudeProvider.snapshot?.quota(for: .session)?.percentRemaining == 70)
        #expect(codexProvider.snapshot?.quota(for: .session)?.percentRemaining == 40)
    }

    @Test
    func `one provider failure does not affect others`() async {
        // Given
        let claudeProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 70, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        ))
        let codexProbe = MockProbe(probeError: ProbeError.timeout)

        let claudeProvider = ClaudeProvider(probe: claudeProbe)
        let codexProvider = CodexProvider(probe: codexProbe)
        let monitor = QuotaMonitor(providers: [claudeProvider, codexProvider])

        // When
        await monitor.refreshAll()

        // Then
        #expect(claudeProvider.snapshot != nil)
        #expect(codexProvider.snapshot == nil)
        #expect(codexProvider.lastError != nil)
    }

    // MARK: - Refresh Others

    @Test
    func `refreshOthers excludes the specified provider`() async {
        // Given
        let claudeProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 70, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        ))
        let codexProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "codex",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "codex")],
            capturedAt: Date()
        ))
        let geminiProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "gemini",
            quotas: [UsageQuota(percentRemaining: 30, quotaType: .session, providerId: "gemini")],
            capturedAt: Date()
        ))

        let claudeProvider = ClaudeProvider(probe: claudeProbe)
        let codexProvider = CodexProvider(probe: codexProbe)
        let geminiProvider = GeminiProvider(probe: geminiProbe)
        let monitor = QuotaMonitor(providers: [claudeProvider, codexProvider, geminiProvider])

        // When - refresh all except Claude
        await monitor.refreshOthers(except: "claude")

        // Then - Codex and Gemini loaded, Claude excluded
        #expect(claudeProvider.snapshot == nil)
        #expect(codexProvider.snapshot?.quota(for: .session)?.percentRemaining == 50)
        #expect(geminiProvider.snapshot?.quota(for: .session)?.percentRemaining == 30)
    }

    // MARK: - Provider Access

    @Test
    func `monitor can find provider by ID`() async {
        // Given
        let probe = MockProbe()
        let provider = ClaudeProvider(probe: probe)
        let monitor = QuotaMonitor(providers: [provider])

        // When
        let found = await monitor.provider(for: "claude")

        // Then
        #expect(found?.id == "claude")
    }

    @Test
    func `monitor returns nil for unknown provider ID`() async {
        // Given
        let monitor = QuotaMonitor(providers: [])

        // When
        let found = await monitor.provider(for: "unknown")

        // Then
        #expect(found == nil)
    }

    // MARK: - Overall Status

    @Test
    func `monitor calculates overall status from all providers`() async {
        // Given
        let claudeProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 70, quotaType: .session, providerId: "claude")], // healthy
            capturedAt: Date()
        ))
        let codexProbe = MockProbe(probeResult: UsageSnapshot(
            providerId: "codex",
            quotas: [UsageQuota(percentRemaining: 15, quotaType: .session, providerId: "codex")], // critical
            capturedAt: Date()
        ))

        let claudeProvider = ClaudeProvider(probe: claudeProbe)
        let codexProvider = CodexProvider(probe: codexProbe)
        let monitor = QuotaMonitor(providers: [claudeProvider, codexProvider])

        await monitor.refreshAll()

        // When
        let overallStatus = await monitor.overallStatus()

        // Then - worst status (critical) wins
        #expect(overallStatus == .critical)
    }

    // MARK: - Continuous Monitoring

    @Test
    func `monitor can start continuous monitoring`() async throws {
        // Given
        let probe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        ))
        let provider = ClaudeProvider(probe: probe)
        let monitor = QuotaMonitor(providers: [provider])

        // When
        let stream = await monitor.startMonitoring(interval: .milliseconds(100))
        var events: [MonitoringEvent] = []

        // Collect first 2 events
        for await event in stream.prefix(2) {
            events.append(event)
        }

        await monitor.stopMonitoring()

        // Then
        #expect(events.count == 2)
        #expect(events.allSatisfy { event in
            if case .refreshed = event { return true }
            return false
        })
    }

    @Test
    func `monitor stops when requested`() async throws {
        // Given
        let probe = MockProbe(probeResult: UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        ))
        let provider = ClaudeProvider(probe: probe)
        let monitor = QuotaMonitor(providers: [provider])

        // When
        let stream = await monitor.startMonitoring(interval: .milliseconds(50))
        await monitor.stopMonitoring()

        var eventCount = 0
        for await _ in stream {
            eventCount += 1
        }

        // Then - Stream should finish quickly after stop
        #expect(eventCount <= 2)
    }
}
