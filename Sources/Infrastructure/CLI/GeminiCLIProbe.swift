import Foundation
import Domain
import os.log

private let logger = Logger(subsystem: "com.claudebar", category: "GeminiCLIProbe")

internal struct GeminiCLIProbe {
    private let timeout: TimeInterval

    init(timeout: TimeInterval) {
        self.timeout = timeout
    }

    func probe() async throws -> UsageSnapshot {
        guard PTYCommandRunner.which("gemini") != nil else {
            throw ProbeError.cliNotFound("gemini")
        }

        logger.info("Starting Gemini CLI fallback...")

        let runner = PTYCommandRunner()
        let options = PTYCommandRunner.Options(
            timeout: timeout,
            extraArgs: []
        )

        let result: PTYCommandRunner.Result
        do {
            result = try runner.run(binary: "gemini", send: "/stats\n", options: options)
        } catch let error as PTYCommandRunner.RunError {
            logger.error("Gemini CLI failed: \(error.localizedDescription)")
            throw mapRunError(error)
        }

        logger.debug("Gemini CLI raw output:\n\(result.text)")

        let snapshot = try Self.parse(result.text)
        logger.info("Gemini CLI probe success: \(snapshot.quotas.count) quotas found")
        return snapshot
    }

    // MARK: - CLI Parsing

    static func parse(_ text: String) throws -> UsageSnapshot {
        let clean = stripANSICodes(text)

        // Check for login errors
        let lower = clean.lowercased()
        if lower.contains("login with google") || lower.contains("use gemini api key") ||
           lower.contains("waiting for auth") {
            throw ProbeError.authenticationRequired
        }

        // Parse model usage table
        let quotas = parseModelUsageTable(clean)

        guard !quotas.isEmpty else {
            throw ProbeError.parseFailed("No usage data found in output")
        }

        return UsageSnapshot(
            providerId: "gemini",
            quotas: quotas,
            capturedAt: Date()
        )
    }

    // MARK: - Text Parsing Helpers

    private static func stripANSICodes(_ text: String) -> String {
        let pattern = #"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func parseModelUsageTable(_ text: String) -> [UsageQuota] {
        let lines = text.components(separatedBy: .newlines)
        var quotas: [UsageQuota] = []

        // Pattern matches: "gemini-2.5-pro   -   100.0% (Resets in 24h)"
        let pattern = #"(gemini[-\w.]+)\s+.*?([0-9]+(?:\.[0-9]+)?)\s*%\s*\(([^)]+)\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return []
        }

        for line in lines {
            let cleanLine = line.replacingOccurrences(of: "│", with: " ")
            let range = NSRange(cleanLine.startIndex..<cleanLine.endIndex, in: cleanLine)
            guard let match = regex.firstMatch(in: cleanLine, options: [], range: range),
                  match.numberOfRanges >= 4 else { continue }

            guard let modelRange = Range(match.range(at: 1), in: cleanLine),
                  let pctRange = Range(match.range(at: 2), in: cleanLine),
                  let pct = Double(cleanLine[pctRange])
            else { continue }

            let modelId = String(cleanLine[modelRange])

            var resetText: String?
            if let resetRange = Range(match.range(at: 3), in: cleanLine) {
                resetText = String(cleanLine[resetRange]).trimmingCharacters(in: .whitespaces)
            }

            quotas.append(UsageQuota(
                percentRemaining: pct,
                quotaType: .modelSpecific(modelId),
                providerId: "gemini",
                resetText: resetText
            ))
        }

        return quotas
    }

    private func mapRunError(_ error: PTYCommandRunner.RunError) -> ProbeError {
        switch error {
        case .binaryNotFound(let bin):
            .cliNotFound(bin)
        case .timedOut:
            .timeout
        case .launchFailed(let msg):
            .executionFailed(msg)
        }
    }
}
