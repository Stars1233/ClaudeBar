import Foundation
import Observation
import Domain

/// What the notch is currently showing, and how big it came out.
///
/// The window controller writes `activity` and `metrics`; the SwiftUI content
/// writes `contentSize` back once it has laid itself out, which is what the
/// window uses to decide which clicks belong to the notch and which fall
/// through to the menu bar.
@MainActor
@Observable
final class NotchViewState {
    /// The single activity worth showing, resolved by `NotchActivityResolver`.
    var activity: NotchActivity?

    /// The measured notch region for the display the window sits on.
    var metrics: NotchMetrics = NotchMetrics(
        closedSize: CGSize(width: NotchMetrics.defaultWidth, height: NotchMetrics.defaultHeight),
        isPhysicalNotch: false
    )

    /// Whether the pointer is over the notch, expanding it into a panel.
    var isExpanded = false

    /// Size of the drawn notch, reported by the content after layout.
    var contentSize: CGSize = .zero

    /// Nothing to say and nothing to hover: the notch is just the notch.
    var isIdle: Bool {
        activity == nil && !isExpanded
    }
}
