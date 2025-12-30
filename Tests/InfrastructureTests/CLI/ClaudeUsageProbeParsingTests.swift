import Testing
import Foundation
@testable import Infrastructure
@testable import Domain

@Suite
struct ClaudeUsageProbeParsingTests {

    // MARK: - Sample CLI Output

    static let sampleClaudeOutput = """
    Claude Code v1.0.27

    Current session
    ████████████████░░░░ 65% left
    Resets in 2h 15m

    Current week (all models)
    ██████████░░░░░░░░░░ 35% left
    Resets Jan 15, 3:30pm (America/Los_Angeles)

    Current week (Opus)
    ████████████████████ 80% left
    Resets Jan 15, 3:30pm (America/Los_Angeles)

    Account: user@example.com
    Organization: Acme Corp
    Login method: Claude Max
    """

    static let exhaustedQuotaOutput = """
    Claude Code v1.0.27

    Current session
    ░░░░░░░░░░░░░░░░░░░░ 0% left
    Resets in 30m

    Current week (all models)
    ██████████░░░░░░░░░░ 35% left
    Resets Jan 15, 3:30pm
    """

    static let usedPercentOutput = """
    Current session
    ████████████████████ 25% used

    Current week (all models)
    ████████████░░░░░░░░ 60% used
    """

    // MARK: - Parsing Percentages

    @Test
    func `parses session quota from left format`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.sessionQuota?.percentRemaining == 65)
        #expect(snapshot.sessionQuota?.status == .healthy)
    }

    @Test
    func `parses weekly quota from left format`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.weeklyQuota?.percentRemaining == 35)
        #expect(snapshot.weeklyQuota?.status == .warning)
    }

    @Test
    func `parses model specific quota like opus`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        let opusQuota = snapshot.quota(for: .modelSpecific("opus"))
        #expect(opusQuota?.percentRemaining == 80)
        #expect(opusQuota?.status == .healthy)
    }

    @Test
    func `converts used format to remaining`() throws {
        // Given
        let output = Self.usedPercentOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then - 25% used = 75% left, 60% used = 40% left
        #expect(snapshot.sessionQuota?.percentRemaining == 75)
        #expect(snapshot.weeklyQuota?.percentRemaining == 40)
    }

    @Test
    func `detects depleted quota at zero percent`() throws {
        // Given
        let output = Self.exhaustedQuotaOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.sessionQuota?.percentRemaining == 0)
        #expect(snapshot.sessionQuota?.status == .depleted)
        #expect(snapshot.sessionQuota?.isDepleted == true)
    }

    // MARK: - Parsing Account Info

    @Test
    func `extracts user email from output`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.accountEmail == "user@example.com")
    }

    @Test
    func `extracts organization from output`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.accountOrganization == "Acme Corp")
    }

    @Test
    func `extracts login method from output`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.loginMethod == "Claude Max")
    }

    // MARK: - Error Detection

    static let trustPromptOutput = """
    Do you trust the files in this folder?
    /Users/test/project

    Yes, proceed (y)
    No, cancel (n)
    """

    static let authErrorOutput = """
    authentication_error: Your session has expired.
    Please run `claude login` to authenticate.
    """

    @Test
    func `detects folder trust prompt and throws error`() throws {
        // Given
        let output = Self.trustPromptOutput

        // When & Then
        #expect(throws: ProbeError.self) {
            try simulateParse(text: output)
        }
    }

    @Test
    func `detects authentication error and throws error`() throws {
        // Given
        let output = Self.authErrorOutput

        // When & Then
        #expect(throws: ProbeError.self) {
            try simulateParse(text: output)
        }
    }

    // MARK: - Reset Time Parsing

    @Test
    func `parses session reset time from output`() throws {
        // Given
        let output = Self.sampleClaudeOutput

        // When
        let snapshot = try ClaudeUsageProbe.parse(output)

        // Then
        let sessionQuota = snapshot.sessionQuota
        #expect(sessionQuota?.resetsAt != nil)
        #expect(sessionQuota?.resetDescription != nil)
    }

    @Test
    func `parses short reset time like 30m`() throws {
        // Given
        let output = Self.exhaustedQuotaOutput

        // When
        let snapshot = try ClaudeUsageProbe.parse(output)

        // Then
        let sessionQuota = snapshot.sessionQuota
        #expect(sessionQuota?.resetsAt != nil)
        // Should be about 30 minutes from now
        if let timeUntil = sessionQuota?.timeUntilReset {
            #expect(timeUntil > 25 * 60) // > 25 minutes
            #expect(timeUntil < 35 * 60) // < 35 minutes
        }
    }

    // MARK: - ANSI Code Handling

    static let ansiColoredOutput = """
    \u{1B}[32mCurrent session\u{1B}[0m
    ████████████████░░░░ \u{1B}[33m65% left\u{1B}[0m
    Resets in 2h 15m
    """

    @Test
    func `strips ansi color codes before parsing`() throws {
        // Given
        let output = Self.ansiColoredOutput

        // When
        let snapshot = try simulateParse(text: output)

        // Then
        #expect(snapshot.sessionQuota?.percentRemaining == 65)
    }

    // MARK: - Account Type Detection from Header

    // /usage header for Max account
    static let maxHeaderOutput = """
    Opus 4.5 · Claude Max · user@example.com's Organization

    Current session
    ████████████████░░░░ 65% left
    Resets in 2h 15m
    """

    // /usage header for Pro account
    static let proHeaderOutput = """
    Opus 4.5 · Claude Pro · Organization

    Current session
    █████░░░░░░░░░░░░░░░ 1% used
    Resets 4:59pm (America/New_York)
    """

    // Real CLI output format with Settings header
    static let realCliOutput = """
    Opus 4.5 · Claude Pro · Some User
    ~/Projects/ClaudeBar

    Settings: Status  Config  Usage (tab to cycle)

    Current session
    ▌                                                  1% used
    Resets 2:59pm (Asia/Shanghai)

    Current week (all models)
    █████                                              16% used
    Resets Dec 25 at 4:59am (Asia/Shanghai)

    Extra usage
    Extra usage not enabled • /extra-usage to enable

    Esc to cancel
    """

    // Real CLI output with ANSI escape codes (from actual terminal)
    static let realCliOutputWithAnsi = """
    \u{1B}[?25l\u{1B}[?2004h\u{1B}[?25h\u{1B}[?2004l\u{1B}[?2026h
    Opus 4.5 · Claude Pro · Some User
    ~/Projects/ClaudeBar

    \u{1B}[33mSettings:\u{1B}[0m Status  Config  \u{1B}[7mUsage\u{1B}[0m (tab to cycle)

    \u{1B}[1mCurrent session\u{1B}[0m
    \u{1B}[34m▌\u{1B}[0m                                                  1% used
    Resets 2:59pm (Asia/Shanghai)

    \u{1B}[1mCurrent week (all models)\u{1B}[0m
    \u{1B}[34m█████\u{1B}[0m                                              16% used
    Resets Dec 25 at 4:59am (Asia/Shanghai)

    \u{1B}[1mExtra usage\u{1B}[0m
    Extra usage not enabled • /extra-usage to enable

    Esc to cancel
    \u{1B}[?2026l
    """

    @Test
    func `parses real CLI output with Settings header`() throws {
        // When
        let snapshot = try ClaudeUsageProbe.parse(Self.realCliOutput)

        // Then
        #expect(snapshot.accountTier == .claudePro)
        #expect(snapshot.accountOrganization == "Some User")
        #expect(snapshot.sessionQuota != nil)
        #expect(snapshot.sessionQuota?.percentRemaining == 99) // 1% used = 99% left
        #expect(snapshot.weeklyQuota != nil)
        #expect(snapshot.weeklyQuota?.percentRemaining == 84) // 16% used = 84% left
        #expect(snapshot.costUsage == nil) // Extra usage not enabled
    }

    @Test
    func `parses real CLI output with ANSI escape codes`() throws {
        // When
        let snapshot = try ClaudeUsageProbe.parse(Self.realCliOutputWithAnsi)

        // Then
        #expect(snapshot.accountTier == .claudePro)
        #expect(snapshot.accountOrganization == "Some User")
        #expect(snapshot.sessionQuota != nil)
        #expect(snapshot.sessionQuota?.percentRemaining == 99) // 1% used = 99% left
        #expect(snapshot.weeklyQuota != nil)
        #expect(snapshot.weeklyQuota?.percentRemaining == 84) // 16% used = 84% left
    }

    @Test
    func `detects Max account type from header`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let accountType = probe.detectAccountType(Self.maxHeaderOutput)

        // Then
        #expect(accountType == .claudeMax)
    }

    @Test
    func `detects Pro account type from header`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let accountType = probe.detectAccountType(Self.proHeaderOutput)

        // Then
        #expect(accountType == .claudePro)
    }

    @Test
    func `detects Max account type from percentage data when no header`() throws {
        // Given
        let probe = ClaudeUsageProbe()
        let output = "Current session\n75% left"

        // When
        let accountType = probe.detectAccountType(output)

        // Then
        #expect(accountType == .claudeMax)
    }

    @Test
    func `defaults to Max when no header but has quota data`() throws {
        // Given
        let probe = ClaudeUsageProbe()
        let output = """
        Current session
        75% left

        Extra usage
        $5.00 / $20.00 spent
        """

        // When
        let accountType = probe.detectAccountType(output)

        // Then - Both Max and Pro can have Extra usage, defaults to Max without header
        #expect(accountType == .claudeMax)
    }

    // MARK: - Extra Usage Parsing

    static let proWithExtraUsageOutput = """
    Opus 4.5 · Claude Pro · Organization

    Current session
    █████░░░░░░░░░░░░░░░ 1% used
    Resets 4:59pm (America/New_York)

    Current week (all models)
    █████████████████░░░ 36% used
    Resets Dec 25 at 2:59pm (America/New_York)

    Extra usage
    █████░░░░░░░░░░░░░░░ 27% used
    $5.41 / $20.00 spent · Resets Jan 1, 2026 (America/New_York)
    """

    static let maxWithExtraUsageNotEnabled = """
    Opus 4.5 · Claude Max · Organization

    Current session
    ████████████████░░░░ 82% used
    Resets 3pm (Asia/Shanghai)

    Extra usage
    Extra usage not enabled · /extra-usage to enable
    """

    @Test
    func `parses Extra usage cost for Pro account`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let costUsage = probe.extractExtraUsage(Self.proWithExtraUsageOutput)

        // Then
        #expect(costUsage != nil)
        #expect(costUsage?.totalCost == Decimal(string: "5.41"))
        #expect(costUsage?.budget == Decimal(string: "20.00"))
    }

    @Test
    func `parses Extra usage cost line`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let result = probe.parseExtraUsageCostLine("$5.41 / $20.00 spent · Resets Jan 1, 2026")

        // Then
        #expect(result != nil)
        #expect(result?.spent == Decimal(string: "5.41"))
        #expect(result?.budget == Decimal(string: "20.00"))
    }

    @Test
    func `parses Extra usage cost line without dollar signs`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let result = probe.parseExtraUsageCostLine("5.41 / 20.00 spent")

        // Then
        #expect(result != nil)
        #expect(result?.spent == Decimal(string: "5.41"))
        #expect(result?.budget == Decimal(string: "20.00"))
    }

    @Test
    func `returns nil for Extra usage not enabled`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let costUsage = probe.extractExtraUsage(Self.maxWithExtraUsageNotEnabled)

        // Then
        #expect(costUsage == nil)
    }

    @Test
    func `returns nil when no Extra usage section`() throws {
        // Given
        let probe = ClaudeUsageProbe()
        let output = """
        Current session
        65% left
        """

        // When
        let costUsage = probe.extractExtraUsage(output)

        // Then
        #expect(costUsage == nil)
    }

    @Test
    func `parse returns snapshot with Extra usage for Pro account`() throws {
        // When
        let snapshot = try ClaudeUsageProbe.parse(Self.proWithExtraUsageOutput)

        // Then
        #expect(snapshot.accountTier == .claudePro)
        #expect(snapshot.costUsage != nil)
        #expect(snapshot.costUsage?.totalCost == Decimal(string: "5.41"))
        #expect(snapshot.costUsage?.budget == Decimal(string: "20.00"))
        #expect(snapshot.quotas.count >= 1)
    }

    // MARK: - Helper

    private func simulateParse(text: String) throws -> UsageSnapshot {
        try ClaudeUsageProbe.parse(text)
    }
}
