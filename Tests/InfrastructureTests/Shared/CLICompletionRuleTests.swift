import Testing
import Foundation
@testable import Infrastructure

@Suite
struct CLICompletionRuleTests {

    /// What `claude /usage` paints within milliseconds of opening the Usage tab —
    /// the cost panel plus a placeholder, before the quota request comes back.
    static let loadingScreen = """
    Claude Code v2.1.251
    Opus 5 (1M context) · Claude Max

      Settings  Status  Config  Usage  Stats

      Session
        Total cost:            $0.0000
        Total duration (API):  0s
        Usage:                 0 input, 0 output, 0 cache read, 0 cache write

        Loading usage data…

      Esc to cancel
    """

    /// The same capture a few seconds later. The PTY buffer is cumulative, so the
    /// placeholder is still in the text — readiness comes from the quota bars.
    static let loadedScreen = loadingScreen + """

      Current session
        ▌                       1% used
        Resets 3:20pm (Asia/Shanghai)
    """

    @Test
    func `output is pending while the placeholder is the only thing rendered`() {
        #expect(CLICompletionRule.claudeUsage.isPending(Self.loadingScreen))
    }

    @Test
    func `output is ready once quota bars arrive even though the placeholder remains`() {
        #expect(!CLICompletionRule.claudeUsage.isPending(Self.loadedScreen))
    }

    @Test
    func `output without a placeholder is never pending`() {
        let costPanelOnly = """
        Opus 5 (1M context) · API Usage Billing
          Session
            Total cost:            $0.0000
        """
        #expect(!CLICompletionRule.claudeUsage.isPending(costPanelOnly))
    }

    @Test
    func `a settled error ends the wait instead of stalling until the timeout`() {
        let rateLimited = Self.loadingScreen + "\nError: Usage endpoint is rate limited. Please try again in a moment."
        #expect(!CLICompletionRule.claudeUsage.isPending(rateLimited))
    }

    @Test
    func `markers match regardless of case`() {
        let rule = CLICompletionRule(pendingMarkers: ["loading"], readyMarkers: ["done"])
        #expect(rule.isPending("LOADING…"))
        #expect(!rule.isPending("LOADING… DONE"))
    }
}
