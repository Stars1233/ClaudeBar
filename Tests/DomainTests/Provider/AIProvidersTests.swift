import Testing
import Foundation
import Mockable
@testable import Domain

@Suite
struct AIProvidersTests {

    // MARK: - All Providers

    @Test
    func `all returns all registered providers`() {
        let providers = AIProviders(providers: [
            ClaudeProvider(probe: MockUsageProbe()),
            CodexProvider(probe: MockUsageProbe()),
            GeminiProvider(probe: MockUsageProbe())
        ])

        #expect(providers.all.count == 3)
    }

    @Test
    func `all returns empty when no providers registered`() {
        let providers = AIProviders(providers: [])

        #expect(providers.all.isEmpty)
    }

    // MARK: - Enabled Providers

    @Test
    func `enabled returns only providers with isEnabled true`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let gemini = GeminiProvider(probe: MockUsageProbe())

        // Disable gemini
        gemini.isEnabled = false

        let providers = AIProviders(providers: [claude, codex, gemini])

        #expect(providers.enabled.count == 2)
        #expect(providers.enabled.contains { $0.id == "claude" })
        #expect(providers.enabled.contains { $0.id == "codex" })
        #expect(!providers.enabled.contains { $0.id == "gemini" })
    }

    @Test
    func `enabled returns empty when all providers disabled`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())

        claude.isEnabled = false
        codex.isEnabled = false

        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.enabled.isEmpty)
    }

    @Test
    func `enabled returns all when all providers enabled`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())

        // Both enabled by default
        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.enabled.count == 2)
    }

    // MARK: - Lookup

    @Test
    func `provider by id returns correct provider`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())

        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.provider(id: "claude")?.name == "Claude")
        #expect(providers.provider(id: "codex")?.name == "Codex")
    }

    @Test
    func `provider by id returns nil for unknown id`() {
        let providers = AIProviders(providers: [
            ClaudeProvider(probe: MockUsageProbe())
        ])

        #expect(providers.provider(id: "unknown") == nil)
    }

    // MARK: - Toggle Enabled State

    @Test
    func `toggling provider isEnabled updates enabled list`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let providers = AIProviders(providers: [claude])

        #expect(providers.enabled.count == 1)

        claude.isEnabled = false

        #expect(providers.enabled.isEmpty)

        claude.isEnabled = true

        #expect(providers.enabled.count == 1)
    }

    // MARK: - Add Provider

    @Test
    func `add appends new provider to all`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let providers = AIProviders(providers: [claude])

        #expect(providers.all.count == 1)

        let codex = CodexProvider(probe: MockUsageProbe())
        providers.add(codex)

        #expect(providers.all.count == 2)
        #expect(providers.all.contains { $0.id == "codex" })
    }

    @Test
    func `add does not duplicate existing provider`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let providers = AIProviders(providers: [claude])

        let anotherClaude = ClaudeProvider(probe: MockUsageProbe())
        providers.add(anotherClaude)

        #expect(providers.all.count == 1)
    }

    @Test
    func `add to empty repository works`() {
        let providers = AIProviders(providers: [])

        #expect(providers.all.isEmpty)

        let claude = ClaudeProvider(probe: MockUsageProbe())
        providers.add(claude)

        #expect(providers.all.count == 1)
        #expect(providers.all.first?.id == "claude")
    }

    // MARK: - Remove Provider

    @Test
    func `remove deletes provider by id`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let codex = CodexProvider(probe: MockUsageProbe())
        let providers = AIProviders(providers: [claude, codex])

        #expect(providers.all.count == 2)

        providers.remove(id: "claude")

        #expect(providers.all.count == 1)
        #expect(providers.all.first?.id == "codex")
    }

    @Test
    func `remove does nothing for unknown id`() {
        let claude = ClaudeProvider(probe: MockUsageProbe())
        let providers = AIProviders(providers: [claude])

        providers.remove(id: "unknown")

        #expect(providers.all.count == 1)
    }

    @Test
    func `remove from empty repository does nothing`() {
        let providers = AIProviders(providers: [])

        providers.remove(id: "claude")

        #expect(providers.all.isEmpty)
    }
}
