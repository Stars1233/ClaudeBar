import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct GeminiUsageProbeParsingTests {

    // MARK: - Sample CLI Output (from /stats command)

    static let sampleCLIOutput = """
    Session Stats

    Model Usage                                                                            Reqs                  Usage left
    ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
    │  gemini-2.5-flash                                                                          -      100.0% (Resets in 24h)  │
    │  gemini-2.5-flash-lite                                                                     -      100.0% (Resets in 24h)  │
    │  gemini-2.5-pro                                                                            -       85.5% (Resets in 24h)  │
    │  gemini-3-pro-preview                                                                      -      100.0% (Resets in 24h)  │

    Usage limits span all sessions and reset daily.
    """

    static let partiallyUsedOutput = """
    Model Usage                                                                            Reqs                  Usage left
    │  gemini-2.5-flash                                                                          5       65.0% (Resets in 12h)  │
    │  gemini-2.5-pro                                                                            3       35.0% (Resets in 12h)  │
    """

    static let exhaustedQuotaOutput = """
    Model Usage                                                                            Reqs                  Usage left
    │  gemini-2.5-pro                                                                           50        0.0% (Resets in 2h)   │
    """

    // MARK: - Parsing Percentages

    @Test
    func `parses model quota from cli output`() throws {
        // Given
        let output = Self.sampleCLIOutput

        // When
        let snapshot = try GeminiUsageProbe.parse(output)

        // Then
        #expect(snapshot.quotas.count == 4)
        #expect(snapshot.providerId == "gemini")
    }

    @Test
    func `parses correct percentages for each model`() throws {
        // Given
        let output = Self.partiallyUsedOutput

        // When
        let snapshot = try GeminiUsageProbe.parse(output)

        // Then
        let flashQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("gemini-2.5-flash") }
        let proQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("gemini-2.5-pro") }

        #expect(flashQuota?.percentRemaining == 65.0)
        #expect(proQuota?.percentRemaining == 35.0)
    }

    @Test
    func `extracts reset text from output`() throws {
        // Given
        let output = Self.partiallyUsedOutput

        // When
        let snapshot = try GeminiUsageProbe.parse(output)

        // Then
        let flashQuota = snapshot.quotas.first { $0.quotaType == .modelSpecific("gemini-2.5-flash") }
        #expect(flashQuota?.resetText == "Resets in 12h")
    }

    @Test
    func `detects depleted quota at zero percent`() throws {
        // Given
        let output = Self.exhaustedQuotaOutput

        // When
        let snapshot = try GeminiUsageProbe.parse(output)

        // Then
        let quota = snapshot.quotas.first
        #expect(quota?.percentRemaining == 0)
        #expect(quota?.status == .depleted)
    }

    // MARK: - Error Detection

    static let notLoggedInOutput = """
    Login with Google to continue
    Use Gemini API key
    """

    @Test
    func `detects not logged in error`() throws {
        // Given
        let output = Self.notLoggedInOutput

        // When & Then
        #expect(throws: ProbeError.self) {
            try GeminiUsageProbe.parse(output)
        }
    }

    static let emptyOutput = """
    Session Stats
    No usage data available
    """

    @Test
    func `throws error when no usage data found`() throws {
        // Given
        let output = Self.emptyOutput

        // When & Then
        #expect(throws: ProbeError.self) {
            try GeminiUsageProbe.parse(output)
        }
    }

    // MARK: - ANSI Code Handling

    static let ansiColoredOutput = """
    \u{1B}[32mModel Usage\u{1B}[0m
    │  gemini-2.5-flash                     -      \u{1B}[33m75.0% (Resets in 6h)\u{1B}[0m  │
    """

    @Test
    func `strips ansi color codes before parsing`() throws {
        // Given
        let output = Self.ansiColoredOutput

        // When
        let snapshot = try GeminiUsageProbe.parse(output)

        // Then
        #expect(snapshot.quotas.first?.percentRemaining == 75.0)
    }
}
