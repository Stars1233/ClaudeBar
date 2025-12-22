import Foundation
import Observation

/// Codex AI provider - a rich domain model.
/// Observable class with its own state (isSyncing, snapshot, error).
@Observable
public final class CodexProvider: AIProvider, @unchecked Sendable {
    // MARK: - Identity

    public let id: String = "codex"
    public let name: String = "Codex"
    public let cliCommand: String = "codex"

    public var dashboardURL: URL? {
        URL(string: "https://platform.openai.com/usage")
    }

    public var statusPageURL: URL? {
        URL(string: "https://status.openai.com")
    }

    // MARK: - State (Observable)

    public private(set) var isSyncing: Bool = false
    public private(set) var snapshot: UsageSnapshot?
    public private(set) var lastError: Error?

    // MARK: - Internal

    private let probe: any UsageProbe

    // MARK: - Initialization

    public init(probe: any UsageProbe) {
        self.probe = probe
    }

    // MARK: - AIProvider Protocol

    public func isAvailable() async -> Bool {
        await probe.isAvailable()
    }

    @discardableResult
    public func refresh() async throws -> UsageSnapshot {
        isSyncing = true
        defer { isSyncing = false }

        do {
            let newSnapshot = try await probe.probe()
            snapshot = newSnapshot
            lastError = nil
            return newSnapshot
        } catch {
            lastError = error
            throw error
        }
    }
}
