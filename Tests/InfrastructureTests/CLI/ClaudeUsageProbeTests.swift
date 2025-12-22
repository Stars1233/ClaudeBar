import Testing
import Foundation
import Mockable
@testable import Infrastructure
@testable import Domain

@Suite
struct ClaudeUsageProbeTests {

    @Test
    func `isAvailable returns true when CLI executor finds binary`() async {
        // Given
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).locate(.any).willReturn("/usr/local/bin/claude")
        let probe = ClaudeUsageProbe(cliExecutor: mockExecutor)

        // When & Then
        #expect(await probe.isAvailable() == true)
    }

    @Test
    func `isAvailable returns false when CLI executor cannot find binary`() async {
        // Given
        let mockExecutor = MockCLIExecutor()
        given(mockExecutor).locate(.any).willReturn(nil)
        let probe = ClaudeUsageProbe(cliExecutor: mockExecutor)

        // When & Then
        #expect(await probe.isAvailable() == false)
    }

    // MARK: - Date Parsing Tests

    @Test
    func `parses reset date with days hours and minutes`() {
        let probe = ClaudeUsageProbe()
        let now = Date()
        
        // Days
        let d2 = probe.parseResetDate("resets in 2d")
        #expect(d2 != nil)
        #expect(d2!.timeIntervalSince(now) > 2 * 23 * 3600) // approx 2 days
        
        // Hours and minutes
        let hm = probe.parseResetDate("resets in 2h 15m")
        #expect(hm != nil)
        let diff = hm!.timeIntervalSince(now)
        #expect(diff > 2 * 3600 + 14 * 60)
        #expect(diff < 2 * 3600 + 16 * 60)
        
        // Just minutes
        let m30 = probe.parseResetDate("30m")
        #expect(m30 != nil)
        #expect(m30!.timeIntervalSince(now) > 29 * 60)
    }

    @Test
    func `parseResetDate returns nil for invalid input`() {
        let probe = ClaudeUsageProbe()
        #expect(probe.parseResetDate(nil) == nil)
        #expect(probe.parseResetDate("") == nil)
        #expect(probe.parseResetDate("no time here") == nil)
    }

    // MARK: - Helper Tests

    @Test
    func `cleanResetText adds resets prefix if missing`() {
        let probe = ClaudeUsageProbe()
        #expect(probe.cleanResetText("in 2h") == "Resets in 2h")
        #expect(probe.cleanResetText("Resets in 2h") == "Resets in 2h")
        #expect(probe.cleanResetText(nil) == nil)
    }

    @Test
    func `extractEmail finds email in various formats`() {
        let probe = ClaudeUsageProbe()
        #expect(probe.extractEmail(text: "Account: user@example.com") == "user@example.com")
        #expect(probe.extractEmail(text: "Email: user@example.com") == "user@example.com")
        #expect(probe.extractEmail(text: "No email here") == nil)
    }

    @Test
    func `extractOrganization finds org`() {
        let probe = ClaudeUsageProbe()
        #expect(probe.extractOrganization(text: "Organization: Acme Corp") == "Acme Corp")
        #expect(probe.extractOrganization(text: "Org: Acme Corp") == "Acme Corp")
    }

    @Test
    func `extractLoginMethod finds method`() {
        let probe = ClaudeUsageProbe()
        #expect(probe.extractLoginMethod(text: "Login method: Claude Max") == "Claude Max")
    }

    @Test
    func `extractFolderFromTrustPrompt finds path`() {
        let probe = ClaudeUsageProbe()
        let output = "Do you trust the files in this folder?\n/Users/test/project\n\nYes/No"
        #expect(probe.extractFolderFromTrustPrompt(output) == "/Users/test/project")
    }

    @Test
    func `probeWorkingDirectory creates and returns URL`() {
        let probe = ClaudeUsageProbe()
        let url = probe.probeWorkingDirectory()
        #expect(url.path.contains("ClaudeBar/Probe"))
        #expect(FileManager.default.fileExists(atPath: url.path))
    }

    // MARK: - Caching Tests

    @Test
    func `probe caches account info and skips status on second call`() async throws {
        // Given
        let mockExecutor = MockCLIExecutor()

        // First call: /status returns Max account
        let statusOutput = """
        Version: 2.0.75
        Login method: Claude Max Account
        Email: user@example.com
        """

        // /usage returns quota data
        let usageOutput = """
        Current session
        ████████████████░░░░ 65% left
        Resets in 2h 15m
        """

        // Setup mock to track call count
        var statusCallCount = 0
        given(mockExecutor).execute(
            binary: .any,
            args: .matching { $0.first == "/status" },
            input: .any,
            timeout: .any,
            workingDirectory: .any,
            sendOnSubstrings: .any
        ).willProduce { _, _, _, _, _, _ in
            statusCallCount += 1
            return CLIResult(output: statusOutput, exitCode: 0)
        }

        given(mockExecutor).execute(
            binary: .any,
            args: .matching { $0.first == "/usage" },
            input: .any,
            timeout: .any,
            workingDirectory: .any,
            sendOnSubstrings: .any
        ).willReturn(CLIResult(output: usageOutput, exitCode: 0))

        let probe = ClaudeUsageProbe(cliExecutor: mockExecutor)

        // When - call probe twice
        _ = try await probe.probe()
        _ = try await probe.probe()

        // Then - /status should only be called once (cached)
        #expect(statusCallCount == 1)
    }

    @Test
    func `clearCache causes status to be called again`() async throws {
        // Given
        let mockExecutor = MockCLIExecutor()

        let statusOutput = """
        Version: 2.0.75
        Login method: Claude Max Account
        Email: user@example.com
        """

        let usageOutput = """
        Current session
        ████████████████░░░░ 65% left
        Resets in 2h 15m
        """

        var statusCallCount = 0
        given(mockExecutor).execute(
            binary: .any,
            args: .matching { $0.first == "/status" },
            input: .any,
            timeout: .any,
            workingDirectory: .any,
            sendOnSubstrings: .any
        ).willProduce { _, _, _, _, _, _ in
            statusCallCount += 1
            return CLIResult(output: statusOutput, exitCode: 0)
        }

        given(mockExecutor).execute(
            binary: .any,
            args: .matching { $0.first == "/usage" },
            input: .any,
            timeout: .any,
            workingDirectory: .any,
            sendOnSubstrings: .any
        ).willReturn(CLIResult(output: usageOutput, exitCode: 0))

        let probe = ClaudeUsageProbe(cliExecutor: mockExecutor)

        // When - call probe, clear cache, call probe again
        _ = try await probe.probe()
        probe.clearCache()
        _ = try await probe.probe()

        // Then - /status should be called twice
        #expect(statusCallCount == 2)
    }

    @Test
    func `probe calls cost command for API account`() async throws {
        // Given
        let mockExecutor = MockCLIExecutor()

        let statusOutput = """
        Version: 2.0.75
        Login method: Claude API Account
        Email: user@example.com
        """

        let costOutput = """
        Total cost: $1.25
        Total duration (API): 10m 30.5s
        Total duration (wall): 1h 15m 0.0s
        Total code changes: 50 lines added, 10 lines removed
        """

        given(mockExecutor).execute(
            binary: .any,
            args: .matching { $0.first == "/status" },
            input: .any,
            timeout: .any,
            workingDirectory: .any,
            sendOnSubstrings: .any
        ).willReturn(CLIResult(output: statusOutput, exitCode: 0))

        given(mockExecutor).execute(
            binary: .any,
            args: .matching { $0.first == "/cost" },
            input: .any,
            timeout: .any,
            workingDirectory: .any,
            sendOnSubstrings: .any
        ).willReturn(CLIResult(output: costOutput, exitCode: 0))

        let probe = ClaudeUsageProbe(cliExecutor: mockExecutor)

        // When
        let snapshot = try await probe.probe()

        // Then
        #expect(snapshot.accountType == .api)
        #expect(snapshot.costUsage != nil)
        #expect(snapshot.costUsage?.totalCost == Decimal(string: "1.25"))
        #expect(snapshot.quotas.isEmpty)
    }
}
