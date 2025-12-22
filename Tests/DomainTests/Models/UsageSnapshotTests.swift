import Testing
import Foundation
@testable import Domain

@Suite
struct UsageSnapshotTests {

    // MARK: - Creating Snapshots

    @Test
    func `snapshot captures quotas for a provider`() {
        // Given
        let quota = UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude")

        // When
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [quota], capturedAt: Date())

        // Then
        #expect(snapshot.providerId == "claude")
        #expect(snapshot.quotas.count == 1)
        #expect(snapshot.quotas.first?.percentRemaining == 65)
    }

    @Test
    func `snapshot can hold multiple quota types`() {
        // Given
        let sessionQuota = UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude")
        let weeklyQuota = UsageQuota(percentRemaining: 35, quotaType: .weekly, providerId: "claude")
        let opusQuota = UsageQuota(percentRemaining: 80, quotaType: .modelSpecific("opus"), providerId: "claude")

        // When
        let snapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [sessionQuota, weeklyQuota, opusQuota],
            capturedAt: Date()
        )

        // Then
        #expect(snapshot.quotas.count == 3)
    }

    // MARK: - Finding Quotas

    @Test
    func `snapshot can find session quota by type`() {
        // Given
        let sessionQuota = UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude")
        let weeklyQuota = UsageQuota(percentRemaining: 35, quotaType: .weekly, providerId: "claude")
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [sessionQuota, weeklyQuota], capturedAt: Date())

        // When
        let found = snapshot.quota(for: .session)

        // Then
        #expect(found?.percentRemaining == 65)
    }

    @Test
    func `snapshot can find weekly quota by type`() {
        // Given
        let sessionQuota = UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude")
        let weeklyQuota = UsageQuota(percentRemaining: 35, quotaType: .weekly, providerId: "claude")
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [sessionQuota, weeklyQuota], capturedAt: Date())

        // When
        let found = snapshot.quota(for: .weekly)

        // Then
        #expect(found?.percentRemaining == 35)
    }

    @Test
    func `snapshot returns nil when quota type not found`() {
        // Given
        let sessionQuota = UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude")
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [sessionQuota], capturedAt: Date())

        // When
        let found = snapshot.quota(for: .weekly)

        // Then
        #expect(found == nil)
    }

    // MARK: - Overall Status

    @Test
    func `overall status is healthy when all quotas are healthy`() {
        // Given
        let quotas = [
            UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
            UsageQuota(percentRemaining: 70, quotaType: .weekly, providerId: "claude"),
        ]
        let snapshot = UsageSnapshot(providerId: "claude", quotas: quotas, capturedAt: Date())

        // When & Then
        #expect(snapshot.overallStatus == .healthy)
    }

    @Test
    func `overall status reflects worst quota when one is warning`() {
        // Given
        let quotas = [
            UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
            UsageQuota(percentRemaining: 35, quotaType: .weekly, providerId: "claude"),
        ]
        let snapshot = UsageSnapshot(providerId: "claude", quotas: quotas, capturedAt: Date())

        // When & Then
        #expect(snapshot.overallStatus == .warning)
    }

    @Test
    func `overall status reflects worst quota when one is critical`() {
        // Given
        let quotas = [
            UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
            UsageQuota(percentRemaining: 15, quotaType: .weekly, providerId: "claude"),
        ]
        let snapshot = UsageSnapshot(providerId: "claude", quotas: quotas, capturedAt: Date())

        // When & Then
        #expect(snapshot.overallStatus == .critical)
    }

    @Test
    func `overall status is depleted when any quota is depleted`() {
        // Given
        let quotas = [
            UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
            UsageQuota(percentRemaining: 0, quotaType: .weekly, providerId: "claude"),
        ]
        let snapshot = UsageSnapshot(providerId: "claude", quotas: quotas, capturedAt: Date())

        // When & Then
        #expect(snapshot.overallStatus == .depleted)
    }

    // MARK: - Freshness

    @Test
    func `snapshot knows how old it is`() {
        // Given
        let capturedAt = Date().addingTimeInterval(-120) // 2 minutes ago
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [], capturedAt: capturedAt)

        // When
        let ageInSeconds = snapshot.age

        // Then
        #expect(ageInSeconds >= 119 && ageInSeconds <= 121)
    }

    @Test
    func `snapshot is stale after 5 minutes`() {
        // Given
        let capturedAt = Date().addingTimeInterval(-360) // 6 minutes ago
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [], capturedAt: capturedAt)

        // When & Then
        #expect(snapshot.isStale == true)
    }

    @Test
    func `snapshot is fresh within 5 minutes`() {
        // Given
        let capturedAt = Date().addingTimeInterval(-60) // 1 minute ago
        let snapshot = UsageSnapshot(providerId: "claude", quotas: [], capturedAt: capturedAt)

        // When & Then
        #expect(snapshot.isStale == false)
    }

    // MARK: - Finding Lowest Quota

    @Test
    func `snapshot finds the quota with lowest percentage`() {
        // Given
        let quotas = [
            UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude"),
            UsageQuota(percentRemaining: 25, quotaType: .weekly, providerId: "claude"),
            UsageQuota(percentRemaining: 60, quotaType: .modelSpecific("opus"), providerId: "claude"),
        ]
        let snapshot = UsageSnapshot(providerId: "claude", quotas: quotas, capturedAt: Date())

        // When
        let lowest = snapshot.lowestQuota

        // Then
        #expect(lowest?.percentRemaining == 25)
        #expect(lowest?.quotaType == .weekly)
    }
}
