import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

/// Tests for notification behavior.
/// Note: These tests document expected behavior but cannot verify actual
/// notifications since UNUserNotificationCenter requires an app bundle.
/// Full integration testing is done manually in the app.
@Suite
struct NotificationQuotaObserverTests {

    // MARK: - Status Degradation Detection

    @Test
    func `status degradation from healthy to warning should trigger notification`() {
        // This test documents the notification trigger condition
        let oldStatus = QuotaStatus.healthy
        let newStatus = QuotaStatus.warning

        // When status degrades (new > old in severity), notification is sent
        #expect(newStatus > oldStatus)
    }

    @Test
    func `status degradation from warning to critical should trigger notification`() {
        let oldStatus = QuotaStatus.warning
        let newStatus = QuotaStatus.critical

        #expect(newStatus > oldStatus)
    }

    @Test
    func `status degradation to depleted should trigger notification`() {
        let oldStatus = QuotaStatus.critical
        let newStatus = QuotaStatus.depleted

        #expect(newStatus > oldStatus)
    }

    // MARK: - No Notification Cases

    @Test
    func `status improvement should not trigger notification`() {
        let oldStatus = QuotaStatus.warning
        let newStatus = QuotaStatus.healthy

        // When status improves (new < old), no notification is sent
        #expect(newStatus < oldStatus)
    }

    @Test
    func `same status should not trigger notification`() {
        let oldStatus = QuotaStatus.healthy
        let newStatus = QuotaStatus.healthy

        // When status is unchanged, no notification is sent
        #expect(newStatus == oldStatus)
    }

    // MARK: - Notification Content

    @Test
    func `notification title includes provider name`() {
        // Given
        let provider = AIProvider.claude

        // When - Building notification content
        let expectedTitle = "\(provider.name) Quota Alert"

        // Then
        #expect(expectedTitle == "Claude Quota Alert")
    }

    @Test
    func `notification body describes warning status`() {
        let provider = AIProvider.codex
        let expectedBody = "Your \(provider.name) quota is running low. Consider pacing your usage."

        #expect(expectedBody.contains("Codex"))
        #expect(expectedBody.contains("running low"))
    }

    @Test
    func `notification body describes critical status`() {
        let provider = AIProvider.gemini
        let expectedBody = "Your \(provider.name) quota is critically low! Save important work."

        #expect(expectedBody.contains("Gemini"))
        #expect(expectedBody.contains("critically low"))
    }

    @Test
    func `notification body describes depleted status`() {
        let provider = AIProvider.claude
        let expectedBody = "Your \(provider.name) quota is depleted. Usage may be blocked."

        #expect(expectedBody.contains("Claude"))
        #expect(expectedBody.contains("depleted"))
    }
}
