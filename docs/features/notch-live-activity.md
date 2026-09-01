# Notch Live Activity

ClaudeBar renders session and quota state into the MacBook notch — a Dynamic Island for Claude Code, built on the hook stream and `QuotaMonitor` that already exist.

**Mockup:** [`docs/mockups/notch-live-activity.html`](../mockups/notch-live-activity.html)

---

## The problem

ClaudeBar already knows everything worth knowing about a running session. `SessionMonitor` consumes a live hook stream (`SessionStart`, `UserPromptSubmit`, `SubagentStart/Stop`, `TaskCompleted`, `Stop`, `SessionEnd`) and maintains a rich `ClaudeSession` with `phase`, `activeSubagentCount`, `completedTaskCount`, and elapsed time. `QuotaMonitor` holds every provider's remaining quota and reset window.

All of it is delivered through two surfaces that are wrong for ambient state:

| Surface | Failure mode |
|---|---|
| **16 px status item** | Fits one number. Sits in a menu bar that macOS 15 crowds and truncates. You have to already be looking at it. |
| **User notifications** | Transient by construction. Focus modes swallow them. `QuotaAlerter` firing at 95% is exactly the message that must not be dismissible-by-default. |
| **Popover** | Requires a click on a target you have to aim for. |

The gap this leaves is specific and daily: **you start Claude in a repo, switch to a browser, and lose all signal about whether it is working, blocked, or finished.** The most expensive case is *blocked* — Claude waiting on a permission prompt while you read Slack, burning wall-clock on a session that needs one keystroke.

`Sources/App/LiveActivity/LiveActivityManager.swift` is already a no-op placeholder documenting this exact intent:

> ActivityKit types are currently marked as explicitly unavailable on macOS — even in macOS 26. When Apple adds macOS support for Live Activities, this manager can be activated to show session status as a system-level Live Activity.

The notch is that surface, available today. It is the only region of the screen that is always visible, never occluded by a window, and already the user's focal point.

## Behavior

Eight states, seven of which read from data ClaudeBar already has. The notch is **collapsed and invisible** by default and only claims space when it has something to say.

| State | Fires on | Reads | Dismissal |
|---|---|---|---|
| **Idle** | no active session | `SessionMonitor.activeSession == nil` | — |
| **Working** | `UserPromptSubmit` | `Phase.active`, elapsed | persists while active |
| **Agents working** | `SubagentStart` | `activeSubagentCount` | persists while active |
| **Needs you** | `Notification` hook *(new)* | permission prompt payload | on resolution — **never times out** |
| **Done** | `Stop` / `SessionEnd` | `completedTaskCount`, duration | auto-retracts after 4 s |
| **Quota threshold** | `QuotaAlerter` 80% / 95% | `QuotaMonitor` | until window resets |
| **Multiple sessions** | concurrent `SessionStart` | sessions keyed by `cwd` | persists |
| **Expanded** | hover / click | same data as the popover | mouse exit |

Two design rules fall out of the state table:

- **Severity wins.** With three sessions running, the collapsed pill shows the worst state across all of them — a blocked session outranks two working ones. The status item cannot express this; the notch can.
- **Attention states do not expire.** `Done` is a four-second flash. `Needs you` and `Quota threshold` stay on screen until the underlying condition clears. This is the property notifications cannot give us.

### The one new hook

`Needs you` is the highest-value state and the only session state needing new plumbing. Claude Code fires a `Notification` hook when it requests permission. Wiring it is two edits:

```swift
// Sources/Infrastructure/Hooks/HookInstaller.swift:22
static let hookEvents = [
    "SessionStart", "SessionEnd", "TaskCompleted",
    "SubagentStart", "SubagentStop", "Stop", "UserPromptSubmit",
    "Notification",                                    // ← new
]

// Sources/Domain/Session/SessionEvent.swift
case notification = "Notification"                     // ← new
```

`ClaudeSession` gains a `.awaitingInput` phase, and `SessionEvent.isClaudeBarProbe` already filters ClaudeBar's own `<AppSupport>/ClaudeBar/Probe` runs so background quota probing does not light the notch.

---

## Prior art

Two open-source implementations were read end to end before designing this.

### boring.notch — [TheBoredTeam/boring.notch](https://github.com/TheBoredTeam/boring.notch)

A full menu bar/HUD replacement: media controls, calendar, battery, file shelf, AirDrop, webcam.

**What it gets right**

*Notch geometry.* `getClosedNotchSize()` in `sizing/matters.swift` is the definitive measurement, and it is not obvious:

```swift
if let topLeftNotchpadding  = screen.auxiliaryTopLeftArea?.width,
   let topRightNotchpadding = screen.auxiliaryTopRightArea?.width {
    notchWidth = screen.frame.width - topLeftNotchpadding - topRightNotchpadding + 4
}

if screen.safeAreaInsets.top > 0 {          // display HAS a notch
    notchHeight = screen.safeAreaInsets.top
} else {                                     // external / non-notch display
    notchHeight = screen.frame.maxY - screen.visibleFrame.maxY   // match menu bar
}
```

The width comes from the *auxiliary areas either side* of the notch, not from any notch API — there isn't one. The `safeAreaInsets.top > 0` test is the canonical has-a-notch check, and the non-notch branch falling back to menu bar height is what makes a virtual notch on an external display look right.

*Fixed window, animated content.* `windowSize` is a constant `640 × 210` canvas, positioned top-centre and never resized. The notch shape is drawn and animated *inside* it. Resizing an `NSWindow` per frame is visibly janky; this sidesteps it entirely.

*`NotchShape`.* A SwiftUI `Shape` with inverted top corners built from quad curves, with `animatableData` over `(topCornerRadius, bottomCornerRadius)` so the corners round out as the notch expands. Descended from MrKai77/DynamicNotchKit. Worth adopting nearly verbatim.

*`sharingType = .none`* to hide the notch from screen recordings — public API, one line, genuinely thoughtful.

**What we will not copy**

Private API, extensively:

```swift
// managers/NotchSpaceManager.swift
notchSpace = CGSSpace(level: 2147483647)   // @_silgen_name into CGSSpaceCreate

// components/Notch/BoringNotchSkyLightWindow.swift
dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/…")
```

`CGSSpace` puts the window in its own max-level space so it floats above fullscreen apps; SkyLight lets it draw on the lock screen. Both are undocumented, both break across macOS releases, and both are disqualifying for a Mac App Store build.

### DynamicNotch — [jackson-storm/DynamicNotch](https://github.com/jackson-storm/DynamicNotch)

Newer, better factored, and the more useful reference for *architecture* rather than geometry.

**The content model is the takeaway.** Rather than one view switching on a mode enum, content sources are protocol-conforming values competing by priority:

```swift
protocol NotchContentProtocol {
    var id: String { get }
    var stackID: String { get }
    var priority: Int { get }
    var isExpandable: Bool { get }
    var expandsOnTap: Bool { get }

    func size(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize
    func expandedSize(baseWidth: CGFloat, baseHeight: CGFloat) -> CGSize
    func cornerRadius(baseRadius: CGFloat) -> (top: CGFloat, bottom: CGFloat)

    @MainActor @ViewBuilder func makeView() -> AnyView
    @MainActor @ViewBuilder func makeExpandedView() -> AnyView
}

enum NotchState {
    case showLiveActivity(NotchContentProtocol)
    case showTemporaryNotification(NotchContentProtocol, duration: TimeInterval)
    case hideLiveActivity(id: String)
    case dismissLiveActivity(id: String)
    case hide
}
```

`NotchModel` then resolves which content wins and derives the window size and corner radii from it. `NotchContentRegistry` is a flat catalogue of descriptors with priorities — `nowPlaying`, `download.active`, `focus.on`, `screen.recording`, `airdrop`.

**This maps exactly onto ClaudeBar's problem.** Session activity, quota alerts and permission prompts are three independent sources competing for one strip of glass, and the `showLiveActivity` / `showTemporaryNotification(duration:)` split *is* the "attention states persist, Done flashes for four seconds" rule from the state table above. That distinction is Apple's Dynamic Island semantics, and both were arrived at independently.

*Panel setup* is clean and reusable:

```swift
window.styleMask       = [.borderless, .nonactivatingPanel]
window.level           = .mainMenu + 3
window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
window.isFloatingPanel = true
window.isOpaque        = false
window.backgroundColor = .clear
window.hasShadow       = false
window.animationBehavior = .none
window.acceptsMouseMovedEvents = true
```

Both projects converged on `.mainMenu + 3` and that exact `collectionBehavior` set. Treat it as the community-settled answer.

**Where it differs, and why we side with boring.notch:** `OverlayPanelWindow` overrides `canBecomeKey`/`canBecomeMain`/`isKeyWindow` to `true`, so the notch takes keyboard focus — which then requires `GlobalClickMonitor` and a 151-line `AppDelegate+OutsideClick` to dismiss it again. boring.notch returns `false` for both and never steals focus. ClaudeBar's notch has no text entry, so `false` is right: **the notch must never pull focus from the terminal the user is working in.**

DynamicNotch also uses SkyLight and `CGShieldingWindowLevel()` for lock-screen presence. Same exclusion as above.

### Comparison

| | boring.notch | DynamicNotch | **ClaudeBar** |
|---|---|---|---|
| Window | `NSPanel` `.mainMenu + 3` | `NSPanel` `.mainMenu + 3` | same |
| Canvas | fixed 640 × 210 | fixed 1000 × 1000 | fixed, ~640 × 280 |
| Takes key focus | no | **yes** | **no** |
| Notch shape | custom `Shape`, animatable radii | custom, animatable radii | adopt boring.notch's |
| Content model | mode enum on one view | **priority protocol + registry** | adopt DynamicNotch's |
| Private API | `CGSSpace` + SkyLight + `dlopen` | SkyLight + `CGShieldingWindowLevel` | **none** |
| Above fullscreen | yes (private) | yes (private) | `.fullScreenAuxiliary` only |
| Lock screen | yes (private) | yes (private) | no |
| MAS-shippable | no | no | **yes** |
| Scope | system HUD replacement | system HUD replacement | **one domain, existing state** |

**The synthesis:** boring.notch's geometry and shape, DynamicNotch's content model, and no private API at all.

### The private-API decision

Declining `CGSSpace` and SkyLight costs two capabilities: the notch will not draw over a fullscreen app on another Space, and will not appear on the lock screen.

That is the right trade for this app, for three reasons that do not apply to either reference project:

1. **`Sources/App/entitlements.mas.plist` exists.** ClaudeBar ships to the Mac App Store. `dlopen` into a PrivateFramework is a review rejection.
2. **Sparkle auto-updates raise the cost of breakage.** A private-API change in a macOS point release becomes a support burden across every installed copy.
3. **The use case does not need it.** ClaudeBar's user is in a terminal and an editor, not a fullscreen game. `.fullScreenAuxiliary` covers auxiliary presentation over the *current* fullscreen space, which is the case that actually occurs.

Both reference apps are HUD replacements whose entire premise requires always-on-top-of-everything. ClaudeBar's notch is a second view onto a menu bar app's existing state. Different premise, different budget for risk.

---

## Architecture

The notch is a **view**, not a new source of truth. `QuotaMonitor` and `SessionMonitor` remain authoritative, per the single-source-of-truth rule in `CLAUDE.md`.

```
Sources/Domain/Notch/
├── NotchActivity.swift            # what could be shown; pure value type
├── NotchActivityResolver.swift    # priority resolution — pure, fully TDD-able
└── NotchPresentation.swift        # .hidden / .collapsed / .expanded

Sources/Infrastructure/Notch/
└── NotchScreenGeometry.swift      # NSScreen measurement (auxiliaryTopLeftArea, safeAreaInsets)

Sources/App/Notch/
├── NotchWindow.swift              # NSPanel subclass; canBecomeKey = false
├── NotchWindowController.swift    # lifecycle, screen changes, positioning
├── NotchShape.swift               # animatable inverted corners
├── NotchRootView.swift            # collapsed lanes + expanded panel
└── Activities/
    ├── SessionActivityView.swift
    ├── AttentionActivityView.swift
    └── QuotaActivityView.swift
```

### The testable core

`NotchActivityResolver` is where the interesting logic lives and it touches no AppKit — a pure function from monitor state to presentation, which is exactly the Chicago-school state-based shape this codebase tests with:

```swift
public struct NotchActivityResolver {
    public func resolve(
        sessions: [ClaudeSession],
        quotas: [ProviderQuota],
        now: Date
    ) -> NotchActivity?
}
```

Rules under test, no mocks required:

- a blocked session outranks any number of working sessions
- a 95% quota alert outranks a working session, but not a blocked one
- `Done` expires at `now > completedAt + 4s` and yields to the next activity
- an ended session with no successor resolves to `nil` → notch hidden
- ClaudeBar's own probe session never produces an activity

### Screen handling

`NotchScreenGeometry` isolates the AppKit measurement so the resolver stays pure:

```swift
struct NotchMetrics {
    let closedSize: CGSize
    let isPhysicalNotch: Bool     // screen.safeAreaInsets.top > 0
}
```

On a display with no notch, the closed height falls back to menu bar height (`screen.frame.maxY - screen.visibleFrame.maxY`) and ClaudeBar draws a virtual notch at top centre — roughly half of installs are on external displays or non-notch Macs, so this is a primary path, not a fallback.

`NSApplication.didChangeScreenParametersNotification` drives re-measurement and repositioning.

### Theming

Both reference apps force `NSAppearance(named: .darkAqua)`. ClaudeBar splits it:

- **the notch region itself is always black** — it is simulating physical glass; a light-themed notch is incoherent
- **the expanded panel themes normally** through `AppThemeProvider`, using `cardGradient` / `glassBorder` / `statusColor(for:)` like every other surface

`ClaudeSession.Phase.color` (`Sources/App/Views/SessionPhaseColor.swift`) is already the single source of truth for phase colour across `StatusBarIcon` and `SessionIndicatorView`; the notch becomes a third consumer, and `.awaitingInput` is added there once.

---

## Delivery

**Phase 1 — the surface.** `NotchWindow`, `NotchShape`, geometry, positioning, multi-display, hover expand. Renders the existing session state only. Proves the hard parts: click-through, no focus stealing, correct measurement on notch and non-notch displays.

**Phase 2 — attention.** `Notification` hook, `.awaitingInput` phase, `NotchActivityResolver` with priority rules, quota threshold state. This is where the feature stops being a demo.

**Phase 3 — multi-session and expanded panel.** Session list keyed by `cwd`, quota bars, actions.

Ships behind `app.notchEnabled` in `settings.json`, default off, with the notch's presence gated on the same `hook.enabled` that already drives `SessionMonitor`.

## Considered and rejected

**Drop a folder on the notch to start a session there.** Both reference apps have a file shelf, so it is the obvious thing to copy. It was cut:

- **Wrong category.** Every other state answers *"what is Claude doing?"*. This one answers *"start Claude"* — an invocation shortcut on an ambient status surface. Mixing the two makes the surface mean less, and a notch that sometimes means "status" and sometimes means "drop zone" is a notch you have to think about.
- **Cost is disproportionate.** It needs a per-screen drag monitor over a screen rect (boring.notch runs a `DragDetector` per display), plus `reRegisterDragDestination`'s staggered re-registration to survive space transitions — real, load-bearing complexity for a shortcut.
- **The payload is worse than the plumbing.** Acting on the drop means launching a *specific* terminal with a scripted `cd … && claude`. That is terminal-specific AppleScript, and effectively impossible under the MAS sandbox — so it would be a non-MAS-only feature bolted to an otherwise clean surface.
- **Users already have faster paths.** `cd` and `claude`, or dragging the folder onto a Terminal tab.

## Open questions

- **Click-through when collapsed.** The window must not consume clicks aimed at menu bar items near screen centre. `ignoresMouseEvents` toggled by an `NSTrackingArea` sized to the current content — needs verification against menu bar item overflow on macOS 15+.
- **Focusing a session's terminal** from the expanded panel needs Accessibility permission, which a sandboxed MAS build cannot have. Keep it an optional non-MAS affordance, not load-bearing.
- **Menu bar auto-hide.** Whether the notch persists when the menu bar hides. Proposal: yes while an activity is live, otherwise no.
- **Interaction with the status item.** Whether the notch replaces the menu bar item or supplements it. Proposal: supplements — the status item remains the click target for the full popover.
