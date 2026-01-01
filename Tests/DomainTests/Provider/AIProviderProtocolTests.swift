import Testing
import Foundation
import Mockable
@testable import Domain

@Suite
struct AIProviderProtocolTests {

    // MARK: - Protocol Conformance

    @Test
    func `provider has required id property`() {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.id == "claude")
    }

    @Test
    func `provider has required name property`() {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.name == "Claude")
    }

    @Test
    func `provider has required cliCommand property`() {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.cliCommand == "claude")
    }

    @Test
    func `provider has dashboardURL property`() {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.dashboardURL != nil)
        #expect(claude.dashboardURL?.absoluteString.contains("anthropic.com") == true)
    }

    @Test
    func `provider delegates isAvailable to probe`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).isAvailable().willReturn(true)
        let claude = ClaudeProvider(probe: mockProbe)

        let isAvailable = await claude.isAvailable()

        #expect(isAvailable == true)
    }

    @Test
    func `provider delegates refresh to probe`() async throws {
        let expectedSnapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        )
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let claude = ClaudeProvider(probe: mockProbe)

        let snapshot = try await claude.refresh()

        #expect(snapshot.quotas.isEmpty)
    }

    // MARK: - Equality via ID

    @Test
    func `providers with same id are equal`() {
        let mockProbe = MockUsageProbe()
        let provider1 = ClaudeProvider(probe: mockProbe)
        let provider2 = ClaudeProvider(probe: mockProbe)

        #expect(provider1.id == provider2.id)
    }

    @Test
    func `different providers have different ids`() {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)
        let codex = CodexProvider(probe: mockProbe)
        let gemini = GeminiProvider(probe: mockProbe)

        #expect(claude.id != codex.id)
        #expect(claude.id != gemini.id)
        #expect(codex.id != gemini.id)
    }

    // MARK: - Provider State

    @Test
    func `provider tracks isSyncing state during refresh`() async throws {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(UsageSnapshot(
            providerId: "claude",
            quotas: [],
            capturedAt: Date()
        ))
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.isSyncing == false)

        _ = try await claude.refresh()

        // After refresh completes, isSyncing should be false again
        #expect(claude.isSyncing == false)
    }

    @Test
    func `provider stores snapshot after refresh`() async throws {
        let expectedSnapshot = UsageSnapshot(
            providerId: "claude",
            quotas: [UsageQuota(percentRemaining: 50, quotaType: .session, providerId: "claude")],
            capturedAt: Date()
        )
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willReturn(expectedSnapshot)
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.snapshot == nil)

        _ = try await claude.refresh()

        #expect(claude.snapshot != nil)
        #expect(claude.snapshot?.quotas.first?.percentRemaining == 50)
    }

    @Test
    func `provider stores error on refresh failure`() async {
        let mockProbe = MockUsageProbe()
        given(mockProbe).probe().willThrow(ProbeError.timeout)
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.lastError == nil)

        do {
            _ = try await claude.refresh()
        } catch {
            // Expected to throw
        }

        #expect(claude.lastError != nil)
    }
}

@Suite(.serialized)
struct AIProviderRegistryTests {

    @Test
    func `registry can register providers`() {
        let registry = AIProviderRegistry.shared
        let providers: [any Domain.AIProvider] = [
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ]

        registry.register(providers)

        #expect(registry.allProviders.count == 3)
    }

    @Test
    func `registry lookup by id returns correct provider`() {
        let registry = AIProviderRegistry.shared
        registry.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        let claude = registry.provider(for: "claude")

        #expect(claude != nil)
        #expect(claude?.name == "Claude")
    }

    @Test
    func `registry lookup with invalid id returns nil`() {
        let registry = AIProviderRegistry.shared
        registry.register([ClaudeProvider(probe: MockUsageProbe())])

        let unknown = registry.provider(for: "unknown")

        #expect(unknown == nil)
    }

    // MARK: - Static Accessors

    @Test
    func `static accessor returns claude provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.claude?.id == "claude")
        #expect(AIProviderRegistry.claude?.name == "Claude")
    }

    @Test
    func `static accessor returns codex provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.codex?.id == "codex")
        #expect(AIProviderRegistry.codex?.name == "Codex")
    }

    @Test
    func `static accessor returns gemini provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.gemini?.id == "gemini")
        #expect(AIProviderRegistry.gemini?.name == "Gemini")
    }

    @Test
    func `static lookup returns nil for unknown provider`() {
        #expect(AIProviderRegistry.provider(for: "unknown-provider") == nil)
    }

    @Test
    func `static lookup by id returns correct provider`() {
        AIProviderRegistry.shared.register([
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(AIProviderRegistry.provider(for: "claude")?.id == "claude")
        #expect(AIProviderRegistry.provider(for: "codex")?.id == "codex")
        #expect(AIProviderRegistry.provider(for: "gemini")?.id == "gemini")
    }
}

// MARK: - Provider Identity Tests

@Suite
struct ProviderIdentityTests {

    @Test
    func `all providers have unique ids`() {
        let providers: [any AIProvider] = [
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ]

        let ids = Set(providers.map(\.id))
        #expect(ids.count == 3)
    }

    @Test
    func `all providers have display names`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.name == "Claude")
        #expect(codex.name == "Codex")
        #expect(gemini.name == "Gemini")
    }

    @Test
    func `provider name matches its identity`() {
        // This tests the rich domain model - name is from provider, not hardcoded
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.id == "claude")
        #expect(claude.name == "Claude")
        #expect(claude.cliCommand == "claude")
    }

    @Test
    func `codex provider has correct identity`() {
        let codex = CodexProvider(probe: MockUsageProbe())

        #expect(codex.id == "codex")
        #expect(codex.name == "Codex")
        #expect(codex.cliCommand == "codex")
    }

    @Test
    func `gemini provider has correct identity`() {
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(gemini.id == "gemini")
        #expect(gemini.name == "Gemini")
        #expect(gemini.cliCommand == "gemini")
    }

    @Test
    func `all providers have dashboard urls`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.dashboardURL != nil)
        #expect(codex.dashboardURL != nil)
        #expect(gemini.dashboardURL != nil)
    }

    @Test
    func `claude dashboard url points to anthropic`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())

        #expect(claude.dashboardURL?.host?.contains("anthropic") == true)
    }

    @Test
    func `codex dashboard url points to openai`() {
        let codex = CodexProvider(probe: MockUsageProbe())

        #expect(codex.dashboardURL?.host?.contains("openai") == true)
    }

    @Test
    func `gemini dashboard url points to google`() {
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(gemini.dashboardURL?.host?.contains("google") == true)
    }

    @Test
    func `providers are enabled by default`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        #expect(claude.isEnabled == true)
        #expect(codex.isEnabled == true)
        #expect(gemini.isEnabled == true)
    }
}

// MARK: - Claude Guest Pass Tests

@Suite
struct ClaudeProviderPassTests {

    @Test
    func `supportsGuestPasses returns true when passProbe is configured`() {
        let mockProbe = MockUsageProbe()
        let mockPassProbe = MockClaudePassProbing()
        let claude = ClaudeProvider(probe: mockProbe, passProbe: mockPassProbe)

        #expect(claude.supportsGuestPasses == true)
    }

    @Test
    func `supportsGuestPasses returns false when passProbe is nil`() {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)

        #expect(claude.supportsGuestPasses == false)
    }

    @Test
    func `fetchPasses throws when passProbe is not configured`() async {
        let mockProbe = MockUsageProbe()
        let claude = ClaudeProvider(probe: mockProbe)

        await #expect(throws: PassError.self) {
            _ = try await claude.fetchPasses()
        }
    }

    @Test
    func `fetchPasses returns pass data on success`() async throws {
        let expectedPass = ClaudePass(
            passesRemaining: 3,
            referralURL: URL(string: "https://claude.ai/referral/ABC123")!
        )
        let mockProbe = MockUsageProbe()
        let mockPassProbe = MockClaudePassProbing()
        given(mockPassProbe).probe().willReturn(expectedPass)
        let claude = ClaudeProvider(probe: mockProbe, passProbe: mockPassProbe)

        let pass = try await claude.fetchPasses()

        #expect(pass.passesRemaining == 3)
        #expect(pass.referralURL.absoluteString == "https://claude.ai/referral/ABC123")
    }

    @Test
    func `fetchPasses returns URL when pass count is unknown`() async throws {
        // Simulates clipboard-only mode where count isn't available
        let expectedPass = ClaudePass(
            referralURL: URL(string: "https://claude.ai/referral/ABC123")!
        )
        let mockProbe = MockUsageProbe()
        let mockPassProbe = MockClaudePassProbing()
        given(mockPassProbe).probe().willReturn(expectedPass)
        let claude = ClaudeProvider(probe: mockProbe, passProbe: mockPassProbe)

        let pass = try await claude.fetchPasses()

        #expect(pass.passesRemaining == nil)
        #expect(pass.referralURL.absoluteString == "https://claude.ai/referral/ABC123")
    }

    @Test
    func `fetchPasses stores guestPass on success`() async throws {
        let expectedPass = ClaudePass(
            passesRemaining: 2,
            referralURL: URL(string: "https://claude.ai/referral/XYZ")!
        )
        let mockProbe = MockUsageProbe()
        let mockPassProbe = MockClaudePassProbing()
        given(mockPassProbe).probe().willReturn(expectedPass)
        let claude = ClaudeProvider(probe: mockProbe, passProbe: mockPassProbe)

        #expect(claude.guestPass == nil)

        _ = try await claude.fetchPasses()

        #expect(claude.guestPass != nil)
        #expect(claude.guestPass?.passesRemaining == 2)
    }

    @Test
    func `fetchPasses tracks isFetchingPasses state`() async throws {
        let mockProbe = MockUsageProbe()
        let mockPassProbe = MockClaudePassProbing()
        given(mockPassProbe).probe().willReturn(ClaudePass(
            passesRemaining: 1,
            referralURL: URL(string: "https://claude.ai/referral/TEST")!
        ))
        let claude = ClaudeProvider(probe: mockProbe, passProbe: mockPassProbe)

        #expect(claude.isFetchingPasses == false)

        _ = try await claude.fetchPasses()

        // After fetch completes, isFetchingPasses should be false again
        #expect(claude.isFetchingPasses == false)
    }

    @Test
    func `fetchPasses stores error on failure`() async {
        let mockProbe = MockUsageProbe()
        let mockPassProbe = MockClaudePassProbing()
        given(mockPassProbe).probe().willThrow(ProbeError.executionFailed("CLI error"))
        let claude = ClaudeProvider(probe: mockProbe, passProbe: mockPassProbe)

        #expect(claude.lastError == nil)

        do {
            _ = try await claude.fetchPasses()
        } catch {
            // Expected to throw
        }

        #expect(claude.lastError != nil)
    }
}
