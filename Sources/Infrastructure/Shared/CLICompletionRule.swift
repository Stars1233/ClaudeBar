import Foundation

/// Tells a PTY run when a TUI screen is actually finished.
///
/// Going idle is not proof that a screen is done. `claude /usage` paints its
/// cost panel plus a `Loading usage data…` placeholder within milliseconds of
/// opening the Usage tab, then fills the quota bars in from a separate request
/// a few seconds later. A capture that stops at the placeholder holds no quota
/// to parse, which surfaced as `Could not find session usage` (issue #271).
///
/// The PTY buffer is cumulative — a redraw appends, it does not erase — so
/// "still loading" cannot be decided by the placeholder disappearing. Readiness
/// is decided by a marker that only the settled screen carries, whether that is
/// the data we wanted or the error that replaced it.
public struct CLICompletionRule: Sendable, Equatable {
    /// Markers whose presence means the screen may still be filling in.
    public let pendingMarkers: [String]
    /// Markers whose presence means the screen has settled, data or error.
    public let readyMarkers: [String]

    public init(pendingMarkers: [String], readyMarkers: [String]) {
        self.pendingMarkers = pendingMarkers
        self.readyMarkers = readyMarkers
    }

    /// True while the output shows a pending marker and no ready marker yet.
    public func isPending(_ text: String) -> Bool {
        guard contains(any: pendingMarkers, in: text) else { return false }
        return !contains(any: readyMarkers, in: text)
    }

    private func contains(any markers: [String], in text: String) -> Bool {
        markers.contains { text.range(of: $0, options: .caseInsensitive) != nil }
    }

    /// The rule for `claude /usage`.
    ///
    /// Ready markers cover both outcomes so a stalled or rate-limited endpoint
    /// ends the wait as soon as the CLI says so, instead of holding the run open
    /// until the probe timeout.
    public static let claudeUsage = CLICompletionRule(
        pendingMarkers: ["Loading usage data"],
        readyMarkers: [
            "Current session",
            "% used",
            "% left",
            "rate limited",
            "Error:",
            "/usage is only available",
        ]
    )
}
