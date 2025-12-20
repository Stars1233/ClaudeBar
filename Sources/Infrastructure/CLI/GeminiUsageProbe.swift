import Foundation
import Domain
import os.log

private let logger = Logger(subsystem: "com.claudebar", category: "GeminiProbe")

/// Infrastructure adapter that probes the Gemini API to fetch usage quotas.
/// Uses OAuth credentials stored by the Gemini CLI, with CLI fallback.
public struct GeminiUsageProbe: UsageProbePort {
    public let provider: AIProvider = .gemini

    private let homeDirectory: String
    private let timeout: TimeInterval
    private let dataLoader: @Sendable (URLRequest) async throws -> (Data, URLResponse)

    private static let quotaEndpoint = "https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota"
    private static let credentialsPath = "/.gemini/oauth_creds.json"

    public init(
        homeDirectory: String = NSHomeDirectory(),
        timeout: TimeInterval = 10.0,
        dataLoader: @escaping @Sendable (URLRequest) async throws -> (Data, URLResponse) = { request in
            try await URLSession.shared.data(for: request)
        }
    ) {
        self.homeDirectory = homeDirectory
        self.timeout = timeout
        self.dataLoader = dataLoader
    }

    public func isAvailable() async -> Bool {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)
        return FileManager.default.fileExists(atPath: credsURL.path)
    }

    public func probe() async throws -> UsageSnapshot {
        logger.info("Starting Gemini probe...")

        // Try CLI first from home directory, fall back to API
        do {
            return try await probeViaCLI()
        } catch {
            logger.warning("Gemini CLI failed: \(error.localizedDescription), trying API fallback...")
            return try await probeViaAPI()
        }
    }

    // MARK: - API Approach

    private func probeViaAPI() async throws -> UsageSnapshot {
        let creds = try loadCredentials()
        logger.debug("Gemini credentials loaded, expiry: \(String(describing: creds.expiryDate))")

        guard let accessToken = creds.accessToken, !accessToken.isEmpty else {
            logger.error("Gemini: No access token found")
            throw ProbeError.authenticationRequired
        }

        guard let url = URL(string: Self.quotaEndpoint) else {
            throw ProbeError.executionFailed("Invalid endpoint URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        request.timeoutInterval = timeout

        let (data, response) = try await dataLoader(request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProbeError.executionFailed("Invalid response")
        }

        logger.debug("Gemini API response status: \(httpResponse.statusCode)")

        if httpResponse.statusCode == 401 {
            logger.error("Gemini: Authentication required (401)")
            throw ProbeError.authenticationRequired
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Gemini: HTTP error \(httpResponse.statusCode)")
            throw ProbeError.executionFailed("HTTP \(httpResponse.statusCode)")
        }

        // Log raw response
        if let jsonString = String(data: data, encoding: .utf8) {
            logger.debug("Gemini API response:\n\(jsonString)")
        }

        let snapshot = try parseAPIResponse(data)
        logger.info("Gemini API probe success: \(snapshot.quotas.count) quotas found")
        for quota in snapshot.quotas {
            logger.info("  - \(quota.quotaType.displayName): \(Int(quota.percentRemaining))% remaining")
        }

        return snapshot
    }

    // MARK: - CLI Approach

    private func probeViaCLI() async throws -> UsageSnapshot {
        guard PTYCommandRunner.which("gemini") != nil else {
            throw ProbeError.cliNotFound("gemini")
        }

        logger.info("Starting Gemini CLI probe...")

        let runner = PTYCommandRunner()
        let options = PTYCommandRunner.Options(
            timeout: 10.0,  // Gemini CLI needs time to authenticate
            workingDirectory: URL(fileURLWithPath: homeDirectory),  // Run from home dir
            extraArgs: [],
            // Wait for the prompt to be ready, send /stats, then exit after seeing results
            sendOnSubstrings: [
                "Type your message": "/stats\n",
                "Usage limits span": "/exit\n",  // Exit after stats shown
                "Resets in": "/exit\n"  // Alternative exit trigger
            ]
        )

        let result: PTYCommandRunner.Result
        do {
            // Don't send anything initially - wait for prompt via sendOnSubstrings
            result = try runner.run(binary: "gemini", send: "", options: options)
        } catch let error as PTYCommandRunner.RunError {
            logger.error("Gemini CLI failed: \(error.localizedDescription)")
            throw mapRunError(error)
        }

        logger.debug("Gemini CLI raw output:\n\(result.text)")

        let snapshot = try Self.parse(result.text)
        logger.info("Gemini CLI probe success: \(snapshot.quotas.count) quotas found")
        return snapshot
    }

    // MARK: - API Parsing

    private func parseAPIResponse(_ data: Data) throws -> UsageSnapshot {
        let decoder = JSONDecoder()
        let response = try decoder.decode(QuotaResponse.self, from: data)

        guard let buckets = response.buckets, !buckets.isEmpty else {
            throw ProbeError.parseFailed("No quota buckets in response")
        }

        // Group quotas by model, keeping lowest per model
        var modelQuotaMap: [String: (fraction: Double, resetTime: String?)] = [:]

        for bucket in buckets {
            guard let modelId = bucket.modelId, let fraction = bucket.remainingFraction else { continue }

            if let existing = modelQuotaMap[modelId] {
                if fraction < existing.fraction {
                    modelQuotaMap[modelId] = (fraction, bucket.resetTime)
                }
            } else {
                modelQuotaMap[modelId] = (fraction, bucket.resetTime)
            }
        }

        let quotas: [UsageQuota] = modelQuotaMap
            .sorted { $0.key < $1.key }
            .map { modelId, data in
                UsageQuota(
                    percentRemaining: data.fraction * 100,
                    quotaType: .modelSpecific(modelId),
                    provider: .gemini,
                    resetText: data.resetTime.map { "Resets \($0)" }
                )
            }

        guard !quotas.isEmpty else {
            throw ProbeError.parseFailed("No valid quotas found")
        }

        return UsageSnapshot(
            provider: .gemini,
            quotas: quotas,
            capturedAt: Date()
        )
    }

    // MARK: - CLI Parsing

    public static func parse(_ text: String) throws -> UsageSnapshot {
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
            provider: .gemini,
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
                provider: .gemini,
                resetText: resetText
            ))
        }

        return quotas
    }

    // MARK: - Credentials

    private struct OAuthCredentials {
        let accessToken: String?
        let refreshToken: String?
        let expiryDate: Date?
    }

    private func loadCredentials() throws -> OAuthCredentials {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)

        guard FileManager.default.fileExists(atPath: credsURL.path) else {
            throw ProbeError.authenticationRequired
        }

        let data = try Data(contentsOf: credsURL)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ProbeError.parseFailed("Invalid credentials file")
        }

        let accessToken = json["access_token"] as? String
        let refreshToken = json["refresh_token"] as? String

        var expiryDate: Date?
        if let expiryMs = json["expiry_date"] as? Double {
            expiryDate = Date(timeIntervalSince1970: expiryMs / 1000)
        }

        return OAuthCredentials(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryDate: expiryDate
        )
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

    // MARK: - Response Types

    private struct QuotaBucket: Decodable {
        let remainingFraction: Double?
        let resetTime: String?
        let modelId: String?
        let tokenType: String?
    }

    private struct QuotaResponse: Decodable {
        let buckets: [QuotaBucket]?
    }
}
