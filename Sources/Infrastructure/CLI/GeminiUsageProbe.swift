import Foundation
import Domain
import os.log

private let logger = Logger(subsystem: "com.claudebar", category: "GeminiProbe")

/// Infrastructure adapter that probes the Gemini API to fetch usage quotas.
/// Uses OAuth credentials stored by the Gemini CLI, with CLI fallback.
public struct GeminiUsageProbe: UsageProbe {
    private let homeDirectory: String
    private let timeout: TimeInterval
    private let networkClient: any NetworkClient

    private static let credentialsPath = "/.gemini/oauth_creds.json"

    public init(
        homeDirectory: String = NSHomeDirectory(),
        timeout: TimeInterval = 10.0,
        networkClient: any NetworkClient = URLSession.shared
    ) {
        self.homeDirectory = homeDirectory
        self.timeout = timeout
        self.networkClient = networkClient
    }

    public func isAvailable() async -> Bool {
        let credsURL = URL(fileURLWithPath: homeDirectory + Self.credentialsPath)
        return FileManager.default.fileExists(atPath: credsURL.path)
    }

    public func probe() async throws -> UsageSnapshot {
        logger.info("Starting Gemini probe...")

        // Strategy: Try CLI first, fall back to API
        // This logic is now coordinated here, while implementation details are in sub-probes.
        
        let apiProbe = GeminiAPIProbe(
            homeDirectory: homeDirectory,
            timeout: timeout,
            networkClient: networkClient
        )
        return try await apiProbe.probe()
        
        // Cli not working reliably, disable for now
        
//        let cliProbe = GeminiCLIProbe(timeout: timeout)
//        
//        do {
//            return try await cliProbe.probe()
//        } catch {
//            logger.warning("Gemini CLI failed: \(error.localizedDescription), trying API fallback...")
//            
//            let apiProbe = GeminiAPIProbe(
//                homeDirectory: homeDirectory,
//                timeout: timeout,
//                networkClient: networkClient
//            )
//            return try await apiProbe.probe()
//        }
    }

    // MARK: - Legacy Parsing Support (for Tests)

    public static func parse(_ text: String) throws -> UsageSnapshot {
        try GeminiCLIProbe.parse(text)
    }
}
