import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

/// Tests for NotificationQuotaObserver.
/// Tests the helper methods that determine notification behavior.
/// Note: Actual notification delivery cannot be tested without an app bundle.
@Suite(.serialized)
struct NotificationQuotaObserverTests {

    // MARK: - Should Notify Tests

    @Test
    func `shouldNotify returns true for warning status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .warning) == true)
    }

    @Test
    func `shouldNotify returns true for critical status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .critical) == true)
    }

    @Test
    func `shouldNotify returns true for depleted status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .depleted) == true)
    }

    @Test
    func `shouldNotify returns false for healthy status`() {
        let observer = NotificationQuotaObserver()

        #expect(observer.shouldNotify(for: .healthy) == false)
    }

    // MARK: - Provider Display Name Tests

    @Test
    func `providerDisplayName uses registry for registered provider`() {
        AIProviderRegistry.shared.reset()
        // Given - register providers using Mockable
        let mockProbe = MockUsageProbe()
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: mockProbe),
            CodexProvider(probe: mockProbe),
            GeminiProvider(probe: mockProbe)
        ])
        let observer = NotificationQuotaObserver()

        // Then - returns provider name from registry
        #expect(observer.providerDisplayName(for: "claude") == "Claude")
        #expect(observer.providerDisplayName(for: "codex") == "Codex")
        #expect(observer.providerDisplayName(for: "gemini") == "Gemini")
    }

    @Test
    func `providerDisplayName capitalizes unknown provider id`() {
        AIProviderRegistry.shared.reset()
        // Given - empty registry
        AIProviderRegistry.shared.register([])
        let observer = NotificationQuotaObserver()

        // Then - capitalizes the ID
        #expect(observer.providerDisplayName(for: "unknown") == "Unknown")
        #expect(observer.providerDisplayName(for: "chatgpt") == "Chatgpt")
    }

    // MARK: - Notification Body Tests

    @Test
    func `notificationBody for warning describes low quota`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .warning, providerName: "Claude")

        #expect(body.contains("Claude"))
        #expect(body.contains("running low"))
    }

    @Test
    func `notificationBody for critical describes critically low`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .critical, providerName: "Codex")

        #expect(body.contains("Codex"))
        #expect(body.contains("critically low"))
    }

    @Test
    func `notificationBody for depleted describes depletion`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .depleted, providerName: "Gemini")

        #expect(body.contains("Gemini"))
        #expect(body.contains("depleted"))
    }

    @Test
    func `notificationBody for healthy describes recovery`() {
        let observer = NotificationQuotaObserver()

        let body = observer.notificationBody(for: .healthy, providerName: "Claude")

        #expect(body.contains("Claude"))
        #expect(body.contains("recovered"))
    }

    // MARK: - Status Degradation Detection (Domain Logic)

    @Test
    func `status degradation from healthy to warning should trigger notification`() {
        // When status degrades (new > old in severity), notification is sent
        #expect(QuotaStatus.warning > QuotaStatus.healthy)
    }

    @Test
    func `status degradation from warning to critical should trigger notification`() {
        #expect(QuotaStatus.critical > QuotaStatus.warning)
    }

    @Test
    func `status degradation to depleted should trigger notification`() {
        #expect(QuotaStatus.depleted > QuotaStatus.critical)
    }

    @Test
    func `status improvement should not trigger notification`() {
        // When status improves (new < old), no notification is sent
        #expect(QuotaStatus.healthy < QuotaStatus.warning)
    }

    @Test
    func `same status should not trigger notification`() {
        // When status is unchanged, no notification is sent
        #expect(QuotaStatus.healthy == QuotaStatus.healthy)
    }

    // MARK: - onStatusChanged Integration Tests

    @Test
    func `onStatusChanged sends notification when status degrades to warning`() async {
        // Given
        let mockService = MockNotificationService()
        given(mockService).send(title: .any, body: .any, categoryIdentifier: .any).willReturn(())
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When
        await observer.onStatusChanged(providerId: "claude", oldStatus: .healthy, newStatus: .warning)

        // Then
        verify(mockService).send(
            title: .matching { $0.contains("Quota Alert") },
            body: .matching { $0.contains("running low") },
            categoryIdentifier: .value("QUOTA_ALERT")
        ).called(1)
    }

    @Test
    func `onStatusChanged sends notification when status degrades to critical`() async {
        // Given
        let mockService = MockNotificationService()
        given(mockService).send(title: .any, body: .any, categoryIdentifier: .any).willReturn(())
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When
        await observer.onStatusChanged(providerId: "codex", oldStatus: .warning, newStatus: .critical)

        // Then
        verify(mockService).send(
            title: .matching { $0.contains("Quota Alert") },
            body: .matching { $0.contains("critically low") },
            categoryIdentifier: .value("QUOTA_ALERT")
        ).called(1)
    }

    @Test
    func `onStatusChanged sends notification when status degrades to depleted`() async {
        // Given
        let mockService = MockNotificationService()
        given(mockService).send(title: .any, body: .any, categoryIdentifier: .any).willReturn(())
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When
        await observer.onStatusChanged(providerId: "gemini", oldStatus: .critical, newStatus: .depleted)

        // Then
        verify(mockService).send(
            title: .matching { $0.contains("Quota Alert") },
            body: .matching { $0.contains("depleted") },
            categoryIdentifier: .value("QUOTA_ALERT")
        ).called(1)
    }

    @Test
    func `onStatusChanged does not send notification when status improves`() async {
        // Given
        let mockService = MockNotificationService()
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When - status improves from warning to healthy
        await observer.onStatusChanged(providerId: "claude", oldStatus: .warning, newStatus: .healthy)

        // Then - no notification sent
        verify(mockService).send(title: .any, body: .any, categoryIdentifier: .any).called(0)
    }

    @Test
    func `onStatusChanged does not send notification when status stays the same`() async {
        // Given
        let mockService = MockNotificationService()
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When - status stays the same
        await observer.onStatusChanged(providerId: "claude", oldStatus: .warning, newStatus: .warning)

        // Then - no notification sent
        verify(mockService).send(title: .any, body: .any, categoryIdentifier: .any).called(0)
    }

    @Test
    func `onStatusChanged silently handles notification errors`() async {
        // Given - service throws an error
        let mockService = MockNotificationService()
        given(mockService).send(title: .any, body: .any, categoryIdentifier: .any).willThrow(NSError(domain: "test", code: 1))
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When & Then - should not throw
        await observer.onStatusChanged(providerId: "claude", oldStatus: .healthy, newStatus: .warning)

        // Verify notification was attempted
        verify(mockService).send(title: .any, body: .any, categoryIdentifier: .any).called(1)
    }

    @Test
    func `requestPermission delegates to notification service`() async {
        // Given
        let mockService = MockNotificationService()
        given(mockService).requestPermission().willReturn(true)
        let observer = NotificationQuotaObserver(notificationService: mockService)

        // When
        let result = await observer.requestPermission()

        // Then
        #expect(result == true)
        verify(mockService).requestPermission().called(1)
    }
}
