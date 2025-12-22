import Foundation
import Domain
import os.log

private let logger = Logger(subsystem: "com.claudebar", category: "CodexProbe")

/// Infrastructure adapter that probes the Codex CLI to fetch usage quotas.
/// Uses JSON-RPC via `codex app-server` for reliable data fetching.
public struct CodexUsageProbe: UsageProbe {
    private let codexBinary: String
    private let timeout: TimeInterval

    public init(codexBinary: String = "codex", timeout: TimeInterval = 20.0) {
        self.codexBinary = codexBinary
        self.timeout = timeout
    }

    public func isAvailable() async -> Bool {
        PTYCommandRunner.which(codexBinary) != nil
    }

    public func probe() async throws -> UsageSnapshot {
        logger.info("Starting Codex probe...")

        // Try RPC first, fall back to TTY
        do {
            let snapshot = try await probeViaRPC()
            logger.info("Codex RPC probe success: \(snapshot.quotas.count) quotas found")
            for quota in snapshot.quotas {
                logger.info("  - \(quota.quotaType.displayName): \(Int(quota.percentRemaining))% remaining")
            }
            return snapshot
        } catch {
            logger.warning("Codex RPC failed: \(error.localizedDescription), trying TTY fallback...")
            let snapshot = try await probeViaTTY()
            logger.info("Codex TTY probe success: \(snapshot.quotas.count) quotas found")
            return snapshot
        }
    }

    // MARK: - RPC Approach

    private func probeViaRPC() async throws -> UsageSnapshot {
        // Use the binary name directly - the RPC client will use /usr/bin/env to find it
        let rpc = try CodexRPCClient(executable: codexBinary, timeout: timeout)
        defer { rpc.shutdown() }

        try await rpc.initialize()
        let limits = try await rpc.fetchRateLimits()

        var quotas: [UsageQuota] = []

        if let primary = limits.primary {
            quotas.append(UsageQuota(
                percentRemaining: max(0, 100 - primary.usedPercent),
                quotaType: .session,
                providerId: "codex",
                resetText: primary.resetDescription
            ))
        }

        if let secondary = limits.secondary {
            quotas.append(UsageQuota(
                percentRemaining: max(0, 100 - secondary.usedPercent),
                quotaType: .weekly,
                providerId: "codex",
                resetText: secondary.resetDescription
            ))
        }

        guard !quotas.isEmpty else {
            throw ProbeError.parseFailed("No rate limits found")
        }

        return UsageSnapshot(
            providerId: "codex",
            quotas: quotas,
            capturedAt: Date()
        )
    }

    // MARK: - TTY Fallback

    private func probeViaTTY() async throws -> UsageSnapshot {
        logger.info("Starting Codex TTY fallback...")

        let runner = PTYCommandRunner()
        let options = PTYCommandRunner.Options(
            timeout: timeout,
            extraArgs: ["-s", "read-only", "-a", "untrusted"]
        )

        let result: PTYCommandRunner.Result
        do {
            result = try runner.run(binary: codexBinary, send: "/status\n", options: options)
        } catch let error as PTYCommandRunner.RunError {
            logger.error("Codex TTY failed: \(error.localizedDescription)")
            throw mapRunError(error)
        }

        logger.debug("Codex TTY raw output:\n\(result.text)")

        let snapshot = try Self.parse(result.text)
        logger.info("Codex TTY success: \(snapshot.quotas.count) quotas")
        return snapshot
    }

    // MARK: - Parsing (for TTY fallback)

    public static func parse(_ text: String) throws -> UsageSnapshot {
        let clean = stripANSICodes(text)

        if let error = extractUsageError(clean) {
            throw error
        }

        let fiveHourPct = extractPercent(labelSubstring: "5h limit", text: clean)
        let weeklyPct = extractPercent(labelSubstring: "Weekly limit", text: clean)

        var quotas: [UsageQuota] = []

        if let fiveHourPct {
            quotas.append(UsageQuota(
                percentRemaining: Double(fiveHourPct),
                quotaType: .session,
                providerId: "codex"
            ))
        }

        if let weeklyPct {
            quotas.append(UsageQuota(
                percentRemaining: Double(weeklyPct),
                quotaType: .weekly,
                providerId: "codex"
            ))
        }

        if quotas.isEmpty {
            throw ProbeError.parseFailed("Could not find usage limits in Codex output")
        }

        return UsageSnapshot(
            providerId: "codex",
            quotas: quotas,
            capturedAt: Date()
        )
    }

    // MARK: - Text Parsing Helpers

    private static func stripANSICodes(_ text: String) -> String {
        let pattern = #"\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])"#
        return text.replacingOccurrences(of: pattern, with: "", options: .regularExpression)
    }

    private static func extractPercent(labelSubstring: String, text: String) -> Int? {
        let lines = text.components(separatedBy: .newlines)
        let label = labelSubstring.lowercased()

        for (idx, line) in lines.enumerated() where line.lowercased().contains(label) {
            let window = lines.dropFirst(idx).prefix(12)
            for candidate in window {
                if let pct = percentFromLine(candidate) {
                    return pct
                }
            }
        }
        return nil
    }

    private static func percentFromLine(_ line: String) -> Int? {
        let pattern = #"([0-9]{1,3})%\s+left"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: range),
              match.numberOfRanges >= 2,
              let valRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return Int(line[valRange])
    }

    private static func extractUsageError(_ text: String) -> ProbeError? {
        let lower = text.lowercased()

        if lower.contains("data not available yet") {
            return .parseFailed("Data not available yet")
        }

        if lower.contains("update available") && lower.contains("codex") {
            return .updateRequired("Codex CLI update required")
        }

        return nil
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

// MARK: - Codex RPC Client

private final class CodexRPCClient: @unchecked Sendable {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let stdoutPipe = Pipe()
    private var nextID = 1

    init(executable: String, timeout: TimeInterval) throws {
        // Build effective PATH including common Node.js installation locations
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        let additionalPaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "\(NSHomeDirectory())/.nvm/versions/node/*/bin",
            "\(NSHomeDirectory())/.local/bin",
            "/usr/local/lib/node_modules/.bin"
        ]
        env["PATH"] = (additionalPaths + [currentPath]).joined(separator: ":")

        process.environment = env
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [executable, "-s", "read-only", "-a", "untrusted", "app-server"]
        process.standardInput = stdinPipe
        process.standardOutput = stdoutPipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            throw ProbeError.executionFailed("Failed to start codex app-server: \(error.localizedDescription)")
        }
    }

    func initialize() async throws {
        _ = try await request(method: "initialize", params: [
            "clientInfo": ["name": "claudebar", "version": "1.0.0"]
        ])
        try sendNotification(method: "initialized")
    }

    struct RateLimitsResponse {
        let primary: RateLimitWindow?
        let secondary: RateLimitWindow?
        let planType: String?

        init(primary: RateLimitWindow?, secondary: RateLimitWindow?, planType: String? = nil) {
            self.primary = primary
            self.secondary = secondary
            self.planType = planType
        }
    }

    struct RateLimitWindow {
        let usedPercent: Double
        let resetDescription: String?
    }

    func fetchRateLimits() async throws -> RateLimitsResponse {
        let message = try await request(method: "account/rateLimits/read")

        // Log raw response
        if let data = try? JSONSerialization.data(withJSONObject: message, options: .prettyPrinted),
           let jsonString = String(data: data, encoding: .utf8) {
            logger.debug("Codex RPC raw response:\n\(jsonString)")
        }

        guard let result = message["result"] as? [String: Any] else {
            logger.error("No result in response: \(String(describing: message))")
            throw ProbeError.parseFailed("Invalid rate limits response")
        }

        guard let rateLimits = result["rateLimits"] as? [String: Any] else {
            logger.error("No rateLimits in result: \(String(describing: result))")
            throw ProbeError.parseFailed("No rateLimits in response")
        }

        let planType = rateLimits["planType"] as? String
        logger.info("Codex plan type: \(planType ?? "unknown")")

        let primary = parseWindow(rateLimits["primary"])
        let secondary = parseWindow(rateLimits["secondary"])

        // If plan is free and no limits, create default "unlimited" quotas
        if primary == nil && secondary == nil {
            if planType == "free" {
                logger.info("Codex free plan - returning unlimited quotas")
                return RateLimitsResponse(
                    primary: RateLimitWindow(usedPercent: 0, resetDescription: "Free plan"),
                    secondary: nil,
                    planType: planType
                )
            }
            // No rate limit data available yet
            throw ProbeError.parseFailed("No rate limits available yet - make some API calls first")
        }

        return RateLimitsResponse(primary: primary, secondary: secondary, planType: planType)
    }

    private func parseWindow(_ value: Any?) -> RateLimitWindow? {
        guard let dict = value as? [String: Any] else {
            logger.debug("parseWindow: value is not a dict: \(String(describing: value))")
            return nil
        }

        logger.debug("parseWindow dict keys: \(dict.keys.joined(separator: ", "))")

        guard let usedPercent = dict["usedPercent"] as? Double else {
            logger.debug("parseWindow: no usedPercent in dict")
            return nil
        }

        var resetDescription: String?
        if let resetsAt = dict["resetsAt"] as? Int {
            let date = Date(timeIntervalSince1970: TimeInterval(resetsAt))
            resetDescription = formatResetTime(date)
        }

        return RateLimitWindow(usedPercent: usedPercent, resetDescription: resetDescription)
    }

    private func formatResetTime(_ date: Date) -> String {
        let interval = date.timeIntervalSinceNow
        if interval <= 0 { return "Resets soon" }

        let hours = Int(interval / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)

        if hours > 0 {
            return "Resets in \(hours)h \(minutes)m"
        } else {
            return "Resets in \(minutes)m"
        }
    }

    func shutdown() {
        if process.isRunning {
            process.terminate()
        }
    }

    // MARK: - JSON-RPC

    private func request(method: String, params: [String: Any]? = nil) async throws -> [String: Any] {
        let id = nextID
        nextID += 1

        try sendRequest(id: id, method: method, params: params)

        while true {
            let message = try await readNextMessage()

            // Skip notifications
            if message["id"] == nil {
                continue
            }

            guard let messageID = message["id"] as? Int, messageID == id else {
                continue
            }

            if let error = message["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                throw ProbeError.executionFailed("RPC error: \(errorMessage)")
            }

            return message
        }
    }

    private func sendNotification(method: String) throws {
        let payload: [String: Any] = ["method": method, "params": [:]]
        try sendPayload(payload)
    }

    private func sendRequest(id: Int, method: String, params: [String: Any]?) throws {
        let payload: [String: Any] = [
            "id": id,
            "method": method,
            "params": params ?? [:]
        ]
        try sendPayload(payload)
    }

    private func sendPayload(_ payload: [String: Any]) throws {
        let data = try JSONSerialization.data(withJSONObject: payload)
        stdinPipe.fileHandleForWriting.write(data)
        stdinPipe.fileHandleForWriting.write(Data([0x0A])) // newline
    }

    private func readNextMessage() async throws -> [String: Any] {
        for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
            guard !line.isEmpty,
                  let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                continue
            }
            return json
        }
        throw ProbeError.executionFailed("Codex app-server closed unexpectedly")
    }
}
