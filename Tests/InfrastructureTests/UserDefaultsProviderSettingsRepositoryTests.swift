import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite("UserDefaultsProviderSettingsRepository Tests")
struct UserDefaultsProviderSettingsRepositoryTests {

    // Use a unique suite name to avoid conflicts with other tests
    private let testSuiteName = "com.claudebar.test.settings.\(UUID().uuidString)"

    private func makeRepository() -> UserDefaultsProviderSettingsRepository {
        let defaults = UserDefaults(suiteName: testSuiteName)!
        return UserDefaultsProviderSettingsRepository(userDefaults: defaults)
    }

    private func cleanupDefaults() {
        UserDefaults().removePersistentDomain(forName: testSuiteName)
    }

    // MARK: - isEnabled Tests

    @Test
    func `isEnabled returns default value when not set`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // When
        let enabledWithTrueDefault = repository.isEnabled(forProvider: "claude", defaultValue: true)
        let enabledWithFalseDefault = repository.isEnabled(forProvider: "codex", defaultValue: false)

        // Then
        #expect(enabledWithTrueDefault == true)
        #expect(enabledWithFalseDefault == false)
    }

    @Test
    func `isEnabled returns stored value when set`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }
        repository.setEnabled(true, forProvider: "claude")

        // When
        let enabled = repository.isEnabled(forProvider: "claude", defaultValue: false)

        // Then
        #expect(enabled == true)
    }

    @Test
    func `isEnabled returns false when explicitly set to false`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }
        repository.setEnabled(false, forProvider: "claude")

        // When
        let enabled = repository.isEnabled(forProvider: "claude", defaultValue: true)

        // Then
        #expect(enabled == false)
    }

    // MARK: - setEnabled Tests

    @Test
    func `setEnabled persists value`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // When
        repository.setEnabled(true, forProvider: "gemini")

        // Then
        let enabled = repository.isEnabled(forProvider: "gemini", defaultValue: false)
        #expect(enabled == true)
    }

    @Test
    func `setEnabled can toggle value`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // When
        repository.setEnabled(true, forProvider: "copilot")
        let enabledFirst = repository.isEnabled(forProvider: "copilot", defaultValue: false)

        repository.setEnabled(false, forProvider: "copilot")
        let enabledSecond = repository.isEnabled(forProvider: "copilot", defaultValue: true)

        // Then
        #expect(enabledFirst == true)
        #expect(enabledSecond == false)
    }

    // MARK: - Provider Isolation Tests

    @Test
    func `settings are isolated per provider`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // When
        repository.setEnabled(true, forProvider: "claude")
        repository.setEnabled(false, forProvider: "codex")

        // Then
        #expect(repository.isEnabled(forProvider: "claude", defaultValue: false) == true)
        #expect(repository.isEnabled(forProvider: "codex", defaultValue: true) == false)
        #expect(repository.isEnabled(forProvider: "gemini", defaultValue: true) == true) // Uses default
    }

    // MARK: - Persistence Tests

    @Test
    func `values persist across repository instances`() {
        // Given
        let defaults = UserDefaults(suiteName: testSuiteName)!
        defer { cleanupDefaults() }

        let repository1 = UserDefaultsProviderSettingsRepository(userDefaults: defaults)
        repository1.setEnabled(true, forProvider: "antigravity")

        // When
        let repository2 = UserDefaultsProviderSettingsRepository(userDefaults: defaults)
        let enabled = repository2.isEnabled(forProvider: "antigravity", defaultValue: false)

        // Then
        #expect(enabled == true)
    }

    // MARK: - Copilot Monthly Limit Tests

    @Test
    func `copilotMonthlyLimit returns nil when not set`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // Then
        #expect(repository.copilotMonthlyLimit() == nil)
    }

    @Test
    func `copilotMonthlyLimit returns stored value when set`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // When
        repository.setCopilotMonthlyLimit(300)

        // Then
        #expect(repository.copilotMonthlyLimit() == 300)
    }

    @Test
    func `setCopilotMonthlyLimit removes value when set to nil`() {
        // Given
        let repository = makeRepository()
        defer { cleanupDefaults() }

        // When - set a value first
        repository.setCopilotMonthlyLimit(300)
        #expect(repository.copilotMonthlyLimit() == 300)

        // Then - clear it by setting nil
        repository.setCopilotMonthlyLimit(nil)
        #expect(repository.copilotMonthlyLimit() == nil)
    }
}
