import Foundation

/// Height policy for the popover's scrollable content region.
///
/// Pure math, kept in Domain so it is unit-testable: the cap must never
/// let content push the action bar off-screen. The popover chrome (header,
/// provider pills, action bar, margins) surrounds the scrollable middle,
/// so the cap is the space that remains once the chrome is on screen.
public enum PopoverContentHeight {
    /// Vertical chrome around the scrollable region (header + pills +
    /// action bar + paddings).
    public static let chrome: CGFloat = 260

    /// Ceiling for overview mode (original design value — overview lists
    /// every provider and prefers a compact window).
    public static let overviewCeiling: CGFloat = 500

    /// Usable floor for degenerate displays: below this, a usable scroll
    /// region is preferred over strict on-screen fit.
    public static let usableFloor: CGFloat = 200

    /// The max height for the scrollable content region.
    /// - Parameters:
    ///   - visibleScreenHeight: `NSScreen.visibleFrame.height` of the
    ///     screen hosting the popover.
    ///   - overviewMode: whether the popover lists all providers.
    public static func maxHeight(visibleScreenHeight: CGFloat, overviewMode: Bool) -> CGFloat {
        let available = max(visibleScreenHeight - chrome, usableFloor)
        return overviewMode ? min(overviewCeiling, available) : available
    }

    /// The height the scrollable region should actually take: its content's,
    /// capped so the action bar cannot be pushed off screen.
    ///
    /// A `ScrollView` is greedy — offered a tall frame it fills it — so a cap
    /// alone is not enough. On a portrait display the cap is over 2000pt, and
    /// a provider with a single card stretched the popover to match it.
    ///
    /// - Parameters:
    ///   - contentHeight: The measured height of the content. Zero or less
    ///     means it has not been measured yet, on the first layout pass.
    ///   - visibleScreenHeight: `NSScreen.visibleFrame.height` of the
    ///     screen hosting the popover.
    ///   - overviewMode: whether the popover lists all providers.
    public static func height(
        contentHeight: CGFloat,
        visibleScreenHeight: CGFloat,
        overviewMode: Bool
    ) -> CGFloat {
        let cap = maxHeight(visibleScreenHeight: visibleScreenHeight, overviewMode: overviewMode)
        // Before the first measurement, prefer the cap: a scrollable popover
        // is recoverable, one collapsed to nothing is not.
        guard contentHeight > 0 else { return cap }
        return min(contentHeight, cap)
    }
}
