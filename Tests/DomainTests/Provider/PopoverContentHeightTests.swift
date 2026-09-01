import Testing
import Foundation
@testable import Domain

@Suite
struct PopoverContentHeightTests {

    // MARK: - Fit Invariant

    @Test(arguments: [560.0, 735.0, 800.0, 982.0, 1200.0])
    func `single-provider cap plus chrome never exceeds the screen`(screenHeight: Double) {
        let cap = PopoverContentHeight.maxHeight(
            visibleScreenHeight: screenHeight,
            overviewMode: false
        )
        #expect(cap + PopoverContentHeight.chrome <= screenHeight)
    }

    @Test(arguments: [560.0, 735.0, 800.0, 982.0, 1200.0])
    func `overview cap plus chrome never exceeds the screen`(screenHeight: Double) {
        let cap = PopoverContentHeight.maxHeight(
            visibleScreenHeight: screenHeight,
            overviewMode: true
        )
        #expect(cap + PopoverContentHeight.chrome <= screenHeight)
    }

    // MARK: - Mode Behavior

    @Test
    func `single-provider cap uses the full remainder on a normal display`() {
        // 14" MacBook Pro visible frame ≈ 982pt → the Oh My Pi card set
        // gets the whole remainder instead of an artificial ceiling.
        let cap = PopoverContentHeight.maxHeight(visibleScreenHeight: 982, overviewMode: false)
        #expect(cap == 982 - PopoverContentHeight.chrome)
    }

    @Test
    func `overview keeps its 500pt ceiling on a normal display`() {
        let cap = PopoverContentHeight.maxHeight(visibleScreenHeight: 982, overviewMode: true)
        #expect(cap == 500)
    }

    @Test
    func `overview shrinks below its ceiling on short displays`() {
        // 735pt visible frame → 500 + chrome would overflow; the remainder wins.
        let cap = PopoverContentHeight.maxHeight(visibleScreenHeight: 735, overviewMode: true)
        #expect(cap == 735 - PopoverContentHeight.chrome)
    }

    // MARK: - Fitting the Content

    @Test
    func `content shorter than the cap keeps its own height`() {
        // A provider with one card must not stretch to fill the cap.
        let height = PopoverContentHeight.height(
            contentHeight: 180,
            visibleScreenHeight: 982,
            overviewMode: false
        )
        #expect(height == 180)
    }

    @Test
    func `content taller than the cap is clamped to it`() {
        let height = PopoverContentHeight.height(
            contentHeight: 5000,
            visibleScreenHeight: 982,
            overviewMode: false
        )
        #expect(height == PopoverContentHeight.maxHeight(visibleScreenHeight: 982, overviewMode: false))
    }

    @Test
    func `a tall display does not stretch a short popover`() {
        // A 2560pt portrait display leaves a ~2300pt cap. Before the content
        // height was taken into account, one small card ballooned to fill it.
        let height = PopoverContentHeight.height(
            contentHeight: 220,
            visibleScreenHeight: 2530,
            overviewMode: false
        )
        #expect(height == 220)
    }

    @Test(arguments: [0.0, -40.0])
    func `an unmeasured content height falls back to the cap`(contentHeight: Double) {
        // First layout pass, before the geometry reader has reported. Falling
        // back to the cap keeps the popover scrollable rather than collapsing
        // it to nothing.
        let height = PopoverContentHeight.height(
            contentHeight: contentHeight,
            visibleScreenHeight: 982,
            overviewMode: false
        )
        #expect(height == PopoverContentHeight.maxHeight(visibleScreenHeight: 982, overviewMode: false))
    }

    @Test
    func `overview still respects its ceiling when content is taller`() {
        let height = PopoverContentHeight.height(
            contentHeight: 5000,
            visibleScreenHeight: 982,
            overviewMode: true
        )
        #expect(height == 500)
    }

    // MARK: - Degenerate Displays

    @Test
    func `degenerate displays get the usable floor instead of collapsing`() {
        let cap = PopoverContentHeight.maxHeight(visibleScreenHeight: 400, overviewMode: false)
        #expect(cap == PopoverContentHeight.usableFloor)
    }
}
