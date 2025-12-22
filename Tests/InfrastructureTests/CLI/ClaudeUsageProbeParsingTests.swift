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

    // MARK: - Account Type Detection

    // /status output for API account (no quota data)
    static let apiAccountOutput = """
    Version: 2.0.75
    Session ID: d248f0a1-f805-4272-9ff8-757dd7c3b83d
    cwd: /github/tddworks/claudebar
    Login method: Claude API Account
    Organization: User's Organization
    Email: user@example.com
    """

    // /status output for Max account (no quota data)
    static let maxAccountOutput = """
    Version: 2.0.75
    Session ID: d248f0a1-f805-4272-9ff8-757dd7c3b83d
    cwd: /github/tddworks/claudebar
    Login method: Claude Max Account
    Organization: User's Organization
    Email: user@example.com
    """

    @Test
    func `detects API account type from login method`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let accountType = probe.detectAccountType(Self.apiAccountOutput)

        // Then
        #expect(accountType == .api)
    }

    @Test
    func `detects Max account type from login method`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let accountType = probe.detectAccountType(Self.maxAccountOutput)

        // Then
        #expect(accountType == .max)
    }

    @Test
    func `detects Max account type from percentage data`() throws {
        // Given
        let probe = ClaudeUsageProbe()
        let output = "Current session\n75% left"

        // When
        let accountType = probe.detectAccountType(output)

        // Then
        #expect(accountType == .max)
    }

    @Test
    func `detects API account type from no usage quotas message`() throws {
        // Given
        let probe = ClaudeUsageProbe()
        let output = "No usage quotas for API accounts."

        // When
        let accountType = probe.detectAccountType(output)

        // Then
        #expect(accountType == .api)
    }

    // MARK: - Cost Parsing

    static let sampleCostOutput = """
    Total cost:            $0.55
    Total duration (API):  6m 19.7s
    Total duration (wall): 6h 33m 10.2s
    Total code changes:    0 lines added, 0 lines removed
    """

    static let largeCostOutput = """
    Total cost: $125.50
    Total duration (API): 2h 15m 30.5s
    Total duration (wall): 48h 0m 0.0s
    Total code changes: 1500 lines added, 250 lines removed
    """

    @Test
    func `parses total cost from cost output`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let cost = probe.extractTotalCost(Self.sampleCostOutput)

        // Then
        #expect(cost == Decimal(string: "0.55"))
    }

    @Test
    func `parses large cost value`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let cost = probe.extractTotalCost(Self.largeCostOutput)

        // Then
        #expect(cost == Decimal(string: "125.50"))
    }

    @Test
    func `parses API duration from cost output`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let duration = probe.extractApiDuration(Self.sampleCostOutput)

        // Then
        // 6m 19.7s = 379.7 seconds
        #expect(duration != nil)
        #expect(abs(duration! - 379.7) < 0.1)
    }

    @Test
    func `parses wall duration from cost output`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let duration = probe.extractWallDuration(Self.sampleCostOutput)

        // Then
        // 6h 33m 10.2s = 23590.2 seconds
        #expect(duration != nil)
        #expect(abs(duration! - 23590.2) < 0.1)
    }

    @Test
    func `parses code changes from cost output`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let changes = probe.extractCodeChanges(Self.largeCostOutput)

        // Then
        #expect(changes.added == 1500)
        #expect(changes.removed == 250)
    }

    @Test
    func `parses zero code changes`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let changes = probe.extractCodeChanges(Self.sampleCostOutput)

        // Then
        #expect(changes.added == 0)
        #expect(changes.removed == 0)
    }

    @Test
    func `parseCost returns snapshot with cost usage`() throws {
        // Given
        let costOutput = Self.sampleCostOutput
        let statusOutput = "Email: test@example.com\nLogin method: Claude API Account"

        // When
        let snapshot = try ClaudeUsageProbe.parseCost(costOutput, statusOutput: statusOutput)

        // Then
        #expect(snapshot.accountType == .api)
        #expect(snapshot.costUsage != nil)
        #expect(snapshot.costUsage?.totalCost == Decimal(string: "0.55"))
        #expect(snapshot.quotas.isEmpty)
        #expect(snapshot.accountEmail == "test@example.com")
    }

    @Test
    func `parseCost extracts all fields correctly`() throws {
        // Given
        let costOutput = Self.largeCostOutput
        let statusOutput = ""

        // When
        let snapshot = try ClaudeUsageProbe.parseCost(costOutput, statusOutput: statusOutput)

        // Then
        let cost = snapshot.costUsage!
        #expect(cost.totalCost == Decimal(string: "125.50"))
        #expect(cost.linesAdded == 1500)
        #expect(cost.linesRemoved == 250)
        #expect(abs(cost.apiDuration - 8130.5) < 0.1) // 2h 15m 30.5s
    }

    // MARK: - Duration String Parsing

    @Test
    func `parses duration with hours minutes seconds`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let duration = probe.parseDurationString("2h 15m 30.5s")

        // Then
        // 2*3600 + 15*60 + 30.5 = 8130.5
        #expect(abs(duration - 8130.5) < 0.1)
    }

    @Test
    func `parses duration with minutes and seconds only`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let duration = probe.parseDurationString("6m 19.7s")

        // Then
        // 6*60 + 19.7 = 379.7
        #expect(abs(duration - 379.7) < 0.1)
    }

    @Test
    func `parses duration with seconds only`() throws {
        // Given
        let probe = ClaudeUsageProbe()

        // When
        let duration = probe.parseDurationString("45.2s")

        // Then
        #expect(abs(duration - 45.2) < 0.1)
    }

    // MARK: - Helper

    private func simulateParse(text: String) throws -> UsageSnapshot {
        try ClaudeUsageProbe.parse(text)
    }
}
