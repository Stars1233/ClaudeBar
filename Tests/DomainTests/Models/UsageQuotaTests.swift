import Testing
import Foundation
@testable import Domain

@Suite
struct UsageQuotaTests {

    // MARK: - Creating Quotas

    @Test
    func `quota can be created with percentage and type`() {
        // Given
        let percentRemaining = 65.0
        let quotaType = QuotaType.session
        let provider = AIProvider.claude

        // When
        let quota = UsageQuota(
            percentRemaining: percentRemaining,
            quotaType: quotaType,
            provider: provider
        )

        // Then
        #expect(quota.percentRemaining == 65)
        #expect(quota.quotaType == .session)
        #expect(quota.provider == .claude)
    }

    @Test
    func `quota can include reset time`() {
        // Given
        let resetDate = Date().addingTimeInterval(3600)

        // When
        let quota = UsageQuota(
            percentRemaining: 35,
            quotaType: .weekly,
            providerId: "claude",
            resetsAt: resetDate
        )

        // Then
        #expect(quota.resetsAt == resetDate)
    }

    // MARK: - Quota Types

    @Test
    func `session quota represents a 5 hour window`() {
        // Given
        let quotaType = QuotaType.session

        // When & Then
        #expect(quotaType.displayName == "Session")
        #expect(quotaType.duration == .hours(5))
    }

    @Test
    func `weekly quota represents a 7 day window`() {
        // Given
        let quotaType = QuotaType.weekly

        // When & Then
        #expect(quotaType.displayName == "Weekly")
        #expect(quotaType.duration == .days(7))
    }

    @Test
    func `model specific quota shows the model name`() {
        // Given
        let quotaType = QuotaType.modelSpecific("opus")

        // When & Then
        #expect(quotaType.displayName == "Opus")
        #expect(quotaType.modelName == "opus")
    }

    // MARK: - Status Thresholds

    @Test
    func `quota with more than 50 percent remaining is healthy`() {
        // Given
        let quota = UsageQuota(percentRemaining: 65, quotaType: .session, providerId: "claude")

        // When & Then
        #expect(quota.status == .healthy)
    }

    @Test
    func `quota between 20 and 50 percent remaining shows warning`() {
        // Given
        let quota = UsageQuota(percentRemaining: 35, quotaType: .session, providerId: "claude")

        // When & Then
        #expect(quota.status == .warning)
    }

    @Test
    func `quota below 20 percent remaining is critical`() {
        // Given
        let quota = UsageQuota(percentRemaining: 15, quotaType: .session, providerId: "claude")

        // When & Then
        #expect(quota.status == .critical)
    }

    @Test
    func `quota at zero percent is depleted`() {
        // Given
        let quota = UsageQuota(percentRemaining: 0, quotaType: .session, providerId: "claude")

        // When & Then
        #expect(quota.status == .depleted)
        #expect(quota.isDepleted == true)
    }

    // MARK: - Comparing Quotas

    @Test
    func `quotas can be sorted by percentage remaining`() {
        // Given
        let highQuota = UsageQuota(percentRemaining: 80, quotaType: .session, providerId: "claude")
        let lowQuota = UsageQuota(percentRemaining: 20, quotaType: .session, providerId: "claude")

        // When & Then
        #expect(highQuota > lowQuota)
        #expect(lowQuota < highQuota)
    }

    @Test
    func `quotas with same percentage are equal`() {
        // Given
        let quota1 = UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude")
        let quota2 = UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude")

        // When & Then
        #expect(quota1 == quota2)
    }
}
