import AppKit
import CoreGraphics
import Domain
import Infrastructure

// MARK: - Particle

private struct Particle {
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var alpha: CGFloat
    let glyph: String
    let size: CGFloat
}

// MARK: - Data Models

public struct TouchBarProviderGauge: Equatable, Sendable {
    public let providerId: String
    public let name: String
    public let percentUsed: Double
    public let resetText: String?
    public let status: QuotaStatus

    public init(
        providerId: String,
        name: String,
        percentUsed: Double,
        resetText: String?,
        status: QuotaStatus
    ) {
        self.providerId = providerId
        self.name = name
        self.percentUsed = percentUsed
        self.resetText = resetText
        self.status = status
    }
}

// MARK: - ClaudePetTouchBarView

/// Interactive Touch Bar view inspired by `tpklo/claude-usage-touchbar`.
/// Renders an animated pixel mascot on the left and live provider usage gauges on the right.
@MainActor
public final class ClaudePetTouchBarView: NSView {
    public static let sceneW: CGFloat = 600.0
    public static let sceneH: CGFloat = 30.0

    // MARK: - Mood

    private enum Mood {
        case calm, brisk, tired, panic, depleted, sleeping

        /// Derive mood from quota data.
        static func from(maxUsage: Double, overallStatus: QuotaStatus, isSleeping: Bool = false) -> Mood {
            if isSleeping || overallStatus == .depleted || Int(maxUsage.rounded()) >= 100 || maxUsage >= 100.0 {
                return .sleeping
            }
            if maxUsage >= 85.0 { return .panic }
            if maxUsage >= 60.0 { return .tired }
            if maxUsage >= 30.0 { return .brisk }
            return .calm
        }

        var speed: CGFloat {
            switch self {
            case .calm:     return 12.0
            case .brisk:    return 24.0
            case .tired:    return 8.0
            case .panic:    return 48.0
            case .depleted: return 0.0
            case .sleeping: return 0.0
            }
        }
    }

    // MARK: - Mascot Position & Physics

    private var x: CGFloat = 40.0
    private var dir: CGFloat = 1.0
    private var phase: CGFloat = 0.0

    // Drag / throw
    private var dragging = false
    private var grabDX: CGFloat = 0.0
    private var dragVX: CGFloat = 0.0
    private var lastDragX: CGFloat = 0.0
    private var throwVX: CGFloat = 0.0
    private var wiggleT: CGFloat = 0.0

    // Jump (triggered on provider switch)
    private var jumpVY: CGFloat = 0.0
    private var jumpY: CGFloat = 0.0

    // MARK: - Event Timers

    /// Body flashes white for this duration (seconds) when status degrades.
    private var flashWhiteT: CGFloat = 0.0
    /// Spinning '?' orbits above head during a quota refresh.
    private var refreshPulseT: CGFloat = 0.0
    private var spinAngle: CGFloat = 0.0

    // MARK: - Idle Tracking

    private var lastActivityTime: TimeInterval = 0
    private var idleElapsed: TimeInterval = 0

    // MARK: - Delta Detection (event reactions)

    private var prevStatus: QuotaStatus = .healthy
    private var prevProviderId: String = ""

    // MARK: - Particles

    private var particles: [Particle] = []

    // MARK: - Cached Context (set on @MainActor, read in draw)

    private var isChristmasTheme: Bool = false
    private var isNightMode: Bool = false
    private var lastNightStarEmit: TimeInterval = 0
    private var lastZzzEmit: TimeInterval = 0

    // MARK: - External Signals

    /// Set by PersistentTouchBarDriver: true when a Claude Code session is active.
    public var sessionActive: Bool = false {
        didSet { needsDisplay = true }
    }

    // MARK: - Gauges + Icons

    public var gauges: [TouchBarProviderGauge] = [] {
        didSet {
            let newStatus = worstStatus(from: gauges)
            let newProviderId = gauges.first?.providerId ?? ""

            // Detect status level transitions
            if prevStatus != newStatus {
                let oldSev = severity(of: prevStatus)
                let newSev = severity(of: newStatus)
                if newSev > oldSev {
                    // Quota degraded → ! alarm particle + body flash
                    spawnParticle(glyph: "!", x: x + CGFloat.random(in: -4...4),
                                  y: 24, vx: 0, vy: 0.7, size: 10)
                    flashWhiteT = 0.12
                } else if newSev < oldSev && oldSev > 0 {
                    // Quota improved (reset) → ✦ sparkle particles
                    spawnParticle(glyph: "✦", x: x - 5, y: 24, vx: -0.3, vy: 0.6, size: 9)
                    spawnParticle(glyph: "✦", x: x + 6, y: 22, vx: 0.3,  vy: 0.7, size: 7)
                }
                prevStatus = newStatus
            }

            // Detect provider switch → jump
            if !prevProviderId.isEmpty && prevProviderId != newProviderId {
                jumpVY = 85.0
                dir = -dir  // face new direction
                markActivity()
            }
            prevProviderId = newProviderId

            // Sync Christmas flag (safe: in @MainActor didSet)
            isChristmasTheme = AppSettings.shared.themeMode == "christmas"

            cachedIcons = gauges.map { loadProviderIcon(for: $0.providerId) }
            if x > petRightBoundary {
                x = petRightBoundary
                dir = -1
            }
            needsDisplay = true
        }
    }
    private var cachedIcons: [NSImage?] = []

    // MARK: - Layout Metrics

    private var cellGap: CGFloat { 12.0 }

    private var readoutWidth: CGFloat {
        guard !gauges.isEmpty else { return 0 }
        let n = CGFloat(gauges.count)
        let desired = n * 170.0 + (n - 1) * cellGap
        return min(380.0, max(200.0, desired))
    }

    private var readoutStartX: CGFloat {
        guard !gauges.isEmpty else { return bounds.width }
        return bounds.width - readoutWidth - 8.0
    }

    /// Safe boundary for Clawd so he turns around comfortably before hitting the progress bar or provider icon
    private var petRightBoundary: CGFloat {
        // Clawd half-width is 17.2pt. Adding 42pt margin ensures a clean ~25pt gap before the first cell.
        return max(40.0, readoutStartX - 42.0)
    }

    // MARK: - Frame Timer

    private var timer: Timer?
    private var lastTick: TimeInterval = 0

    // MARK: - Clawd 20x20 Base Sprite Grid

    private static let baseGrid: [UInt8] = [
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
        0, 0, 0, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 1, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0
    ]

    // MARK: - Init

    public override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.sceneW, height: Self.sceneH))
        self.allowedTouchTypes = [.direct]
        lastActivityTime = Date.timeIntervalSinceReferenceDate
        startAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool { false }
    public override var acceptsFirstResponder: Bool { true }

    // MARK: - Animation Control

    public func startAnimation() {
        guard timer == nil else { return }
        lastTick = Date.timeIntervalSinceReferenceDate
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.step()
            }
        }
        if let timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    public func stopAnimation() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - External Trigger

    /// Called by PersistentTouchBarDriver to show a refresh animation while quotas reload.
    public func triggerRefreshPulse() {
        refreshPulseT = 1.5
        spinAngle = 0
    }

    // MARK: - Animation Step

    private func step() {
        let now = Date.timeIntervalSinceReferenceDate
        let dt = min(0.1, max(0.001, now - lastTick))
        lastTick = now

        // Track idle elapsed time
        idleElapsed = now - lastActivityTime

        // Night mode (22:00–04:59 local time)
        let hour = Calendar.current.component(.hour, from: Date())
        isNightMode = hour >= 22 || hour < 5

        let maxUsage = gauges.map(\.percentUsed).max() ?? 0
        let overallSt = worstStatus(from: gauges)
        let mood = Mood.from(maxUsage: maxUsage, overallStatus: overallSt)
        let isSleeping = (mood == .sleeping)

        // Speed modifiers
        let sessionMult: CGFloat = sessionActive ? 1.5 : 1.0   // +50% when Claude Code active
        let nightMult: CGFloat   = isNightMode   ? 0.6 : 1.0   // -40% at night

        // Decay event timers
        if flashWhiteT > 0   { flashWhiteT   = max(0, flashWhiteT   - CGFloat(dt)) }
        if refreshPulseT > 0 {
            refreshPulseT = max(0, refreshPulseT - CGFloat(dt))
            spinAngle += CGFloat(dt) * CGFloat.pi * 5.0
        }

        // Update particles (move + fade)
        particles = particles.compactMap { var p = $0
            p.x += p.vx
            p.y += p.vy
            p.alpha -= 0.028
            return p.alpha > 0 ? p : nil
        }

        // Jump physics (triggered on provider switch)
        if jumpVY != 0 || jumpY > 0 {
            jumpVY -= 300.0 * CGFloat(dt)
            jumpY   = max(0, jumpY + jumpVY * CGFloat(dt))
            if jumpY <= 0 { jumpY = 0; jumpVY = 0 }
        }

        // Night star emission (every ~4 s)
        if isNightMode && now - lastNightStarEmit > 4.0 {
            lastNightStarEmit = now
            spawnParticle(glyph: "✦",
                          x: x + CGFloat.random(in: -4...8),
                          y: 22, vx: CGFloat.random(in: 0.1...0.4), vy: 0.5, size: 7)
        }

        // Zzz emission when sleeping (every 2 s)
        if isSleeping && now - lastZzzEmit > 2.0 {
            lastZzzEmit = now
            spawnParticle(glyph: "z", x: x + dir * 8.0, y: 22, vx: dir * 0.2, vy: 0.5, size: 8)
        }

        let rightLimit = petRightBoundary
        let pad: CGFloat = 24.0

        // Depleted: Clawd lies flat, no movement
        if mood == .depleted {
            needsDisplay = true
            return
        }

        if dragging {
            phase += dt * 17.0
            wiggleT += dt
            needsDisplay = true
            return
        }

        if abs(throwVX) > 1.0 {
            x += throwVX * CGFloat(dt)
            throwVX *= 0.92
            if x < pad         { x = pad;         throwVX = -throwVX * 0.5; dir =  1 }
            if x > rightLimit  { x = rightLimit;  throwVX = -throwVX * 0.5; dir = -1 }
            phase += CGFloat(dt) * (abs(throwVX) / 9.0)
            needsDisplay = true
            return
        }

        // Sleeping: stand still, no movement
        if isSleeping {
            needsDisplay = true
            return
        }

        // Keep walking at all times (always awake when quota < 100%)
        let finalSpeed = mood.speed * sessionMult * nightMult
        x += dir * finalSpeed * CGFloat(dt)
        if x > rightLimit { x = rightLimit; dir = -1 }
        if x < pad        { x = pad;        dir =  1 }
        phase += CGFloat(dt) * (finalSpeed / 9.0)

        needsDisplay = true
    }

    // MARK: - Touch Interaction

    public override func touchesBegan(with event: NSEvent) {
        guard let touch = event.touches(matching: .any, in: self).first else { return }
        let tx = touch.location(in: self).x

        // Tap on readout area → open ClaudeBar
        if tx >= readoutStartX - 10.0 {
            NSWorkspace.shared.open(URL(string: "claudebar://open")!)
            return
        }

        // Grab Clawd if close
        if abs(tx - x) < 36.0 {
            dragging  = true
            grabDX    = tx - x
            dragVX    = 0
            lastDragX = tx
            markActivity()
        }
    }

    public override func touchesMoved(with event: NSEvent) {
        guard dragging, let touch = event.touches(matching: .any, in: self).first else { return }
        let tx = touch.location(in: self).x
        let nx = tx - grabDX
        dragVX    = tx - lastDragX
        lastDragX = tx

        x = max(24.0, min(nx, petRightBoundary))

        if abs(dragVX) > 0.5 { dir = (dragVX > 0) ? 1 : -1 }
        needsDisplay = true
    }

    public override func touchesEnded(with event: NSEvent)    { releaseDrag() }
    public override func touchesCancelled(with event: NSEvent) { releaseDrag() }

    private func releaseDrag() {
        guard dragging else { return }
        dragging = false
        throwVX  = dragVX * 12.0
        markActivity()
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        let maxUsage = gauges.map(\.percentUsed).max() ?? 0
        let overallSt = worstStatus(from: gauges)
        let mood = Mood.from(maxUsage: maxUsage, overallStatus: overallSt)

        // Ground line across the Touch Bar
        NSColor(white: 1.0, alpha: 0.14).set()
        NSRect(x: 0, y: 1.0, width: bounds.width, height: 1.0).fill()

        drawMascot(mood: mood)
        drawReadout()
    }

    // MARK: - Mascot Drawing

    private func drawMascot(mood: Mood) {
        let px: CGFloat = 1.72
        let feetX: CGFloat = x
        let baseGroundY: CGFloat = 2.2 + jumpY   // jumpY > 0 during provider-switch bounce

        // Session glow ring: subtle orange oval beneath feet when Claude Code is active
        if sessionActive {
            NSColor(srgbRed: 0.98, green: 0.55, blue: 0.0, alpha: 0.30).set()
            NSBezierPath(ovalIn: NSRect(x: feetX - 13, y: baseGroundY - 1.5, width: 26, height: 5)).fill()
        }

        // Depleted: Clawd lies flat on ground
        if mood == .depleted {
            drawDepletedMascot(x: feetX, y: baseGroundY, px: px)
            drawParticles()
            return
        }

        let isFlipped = dir < 0
        let isSitting  = false
        let isSleeping = mood == .sleeping

        // Body color: white flash on status upgrade, else 100% provider brand color
        let bodyColor: NSColor
        if flashWhiteT > 0 {
            bodyColor = NSColor(white: 1.0, alpha: 0.95)
        } else {
            let activePid = gauges.first?.providerId ?? "claude"
            bodyColor = providerBodyColor(for: activePid, mood: mood)
        }
        let eyeColor = NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 1.0)

        // Bob: disabled when tired / sitting / sleeping
        let bob: CGFloat
        if mood == .tired || isSitting || isSleeping { bob = 0 }
        else { bob = ((Int(phase * 2.0) & 1) == 1) ? 0.7 : 0 }
        let feetY = baseGroundY + bob

        // Panic motion streaks
        if mood == .panic {
            bodyColor.withAlphaComponent(0.28).set()
            for i in 1...3 {
                let sx = feetX - dir * (20.0 * px * 0.4 + CGFloat(i) * 5.0)
                NSRect(x: min(sx, sx - dir * 4.0), y: feetY + 8.0, width: 4.0, height: 1.6).fill()
            }
        }

        // Build sprite frame, then apply mood expression on top
        let walkStep = (isSitting || isSleeping) ? 0 : Int(phase * 2.0)
        var sprite = Self.walkFrame(step: walkStep)
        applyExpression(&sprite, mood: mood)

        for r in 3...17 {
            for c in 0..<20 {
                let v = sprite[r * 20 + c]
                if v == 0 { continue }
                let ink = (v == 2) ? eyeColor : bodyColor
                ink.set()
                let cx = isFlipped ? (19 - c) : c
                let rowUp = CGFloat(17 - r)
                NSRect(
                    x: feetX + (CGFloat(cx) - 10.0) * px,
                    y: feetY + rowUp * px,
                    width: px + 0.4,
                    height: px + 0.4
                ).fill()
            }
        }

        // Tired sweat drop
        if mood == .tired {
            NSColor(srgbRed: 0.42, green: 0.70, blue: 0.94, alpha: 0.95).set()
            NSRect(x: feetX + 8.0, y: feetY + 13.0 * px * 0.9, width: 2.4, height: 3.4).fill()
        }

        // Christmas hat (when christmas theme is active)
        if isChristmasTheme {
            drawChristmasHat(centerX: feetX, feetY: feetY, px: px, flipped: isFlipped)
        }

        // Refresh pulse: '?' orbits above head
        if refreshPulseT > 0 {
            let headTopY   = feetY + 14.0 * px
            let orbitR: CGFloat = 7.0
            let qx = feetX + cos(spinAngle) * orbitR
            let qy = headTopY + sin(spinAngle) * orbitR * 0.5
            let pulseAlpha = min(1.0, refreshPulseT * 1.5)
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 9, weight: .bold),
                .foregroundColor: NSColor(white: 1.0, alpha: pulseAlpha)
            ]
            ("?" as NSString).draw(at: NSPoint(x: qx - 3, y: qy), withAttributes: attr)
        }

        // Draw floating particles on top
        drawParticles()
    }

    /// Draw Clawd lying flat when all quota is depleted.
    private func drawDepletedMascot(x: CGFloat, y: CGFloat, px: CGFloat) {
        let bodyColor = NSColor(white: 0.50, alpha: 0.80)
        bodyColor.set()
        // Two horizontal rows — lying body shape
        for c in 3...16 {
            NSRect(x: x + CGFloat(c - 10) * px, y: y + 3.5,              width: px + 0.4, height: px + 0.4).fill()
            NSRect(x: x + CGFloat(c - 10) * px, y: y + 3.5 + (px + 0.4), width: px + 0.4, height: px + 0.4).fill()
        }
        // Flat closed eyes (— —)
        NSColor(srgbRed: 0.06, green: 0.06, blue: 0.06, alpha: 0.7).set()
        NSRect(x: x - 4.5, y: y + 4.5, width: 3.8, height: 0.9).fill()
        NSRect(x: x + 1.5, y: y + 4.5, width: 3.8, height: 0.9).fill()
    }

    /// Draw a tiny pixel Santa hat above Clawd's head when Christmas theme is active.
    private func drawChristmasHat(centerX: CGFloat, feetY: CGFloat, px: CGFloat, flipped: Bool) {
        let headTopY: CGFloat = feetY + 14.5 * px
        let tipOffsetX: CGFloat = flipped ? 3.5 : -3.5

        // Red triangular body
        NSColor(srgbRed: 0.80, green: 0.10, blue: 0.10, alpha: 1.0).set()
        let hatPath = NSBezierPath()
        hatPath.move(to: NSPoint(x: centerX - 7,          y: headTopY))
        hatPath.line(to: NSPoint(x: centerX + 7,          y: headTopY))
        hatPath.line(to: NSPoint(x: centerX + tipOffsetX, y: headTopY + 9))
        hatPath.close()
        hatPath.fill()

        // White brim strip
        NSColor(white: 0.92, alpha: 0.95).set()
        NSRect(x: centerX - 8, y: headTopY - 1, width: 16, height: 2.5).fill()

        // White pompom at tip
        NSColor(white: 0.95, alpha: 1.0).set()
        NSBezierPath(ovalIn: NSRect(
            x: centerX + tipOffsetX - 2.5,
            y: headTopY + 6.5,
            width: 5, height: 5
        )).fill()
    }

    // MARK: - Expression System

    /// Overwrite eye pixels (value == 2) in the sprite to reflect current mood.
    private func applyExpression(_ sprite: inout [UInt8], mood: Mood) {
        // Clear all existing eye pixels
        for i in 0..<sprite.count where sprite[i] == 2 { sprite[i] = 1 }

        // Bounds-safe setter
        func setEye(_ r: Int, _ c: Int) {
            let idx = r * 20 + c
            guard idx >= 0, idx < sprite.count else { return }
            sprite[idx] = 2
        }

        switch mood {
        case .calm, .brisk:
            // Normal dot eyes: r=6, c=7 and c=13
            setEye(6, 7);  setEye(6, 13)

        case .tired:
            // Drooping — one row lower
            setEye(7, 7);  setEye(7, 13)

        case .panic:
            // Wide, spread — 2 pixels each, slightly wider
            setEye(6, 6);  setEye(6, 7)
            setEye(6, 13); setEye(6, 14)

        case .depleted, .sleeping:
            // Flat closed bars: ——  ——
            setEye(7, 6);  setEye(7, 7);  setEye(7, 8)
            setEye(7, 12); setEye(7, 13); setEye(7, 14)
        }
    }

    // MARK: - Provider Body Color

    /// Clawd's body color: 100% active provider brand color (or default terracotta for Claude).
    private func providerBodyColor(for providerId: String, mood: Mood) -> NSColor {
        let base = NSColor(srgbRed: 0.804, green: 0.498, blue: 0.416, alpha: 1.0)

        let tint: NSColor?
        switch providerId.lowercased() {
        case "claude":
            tint = base
        case "gemini":
            tint = NSColor(srgbRed: 0.91, green: 0.72, blue: 0.27, alpha: 1.0)  // golden
        case "copilot":
            tint = NSColor(srgbRed: 0.38, green: 0.55, blue: 0.93, alpha: 1.0)  // indigo
        case "antigravity":
            tint = NSColor(srgbRed: 0.72, green: 0.35, blue: 0.85, alpha: 1.0)  // violet
        case "codex":
            tint = NSColor(srgbRed: 0.18, green: 0.72, blue: 0.68, alpha: 1.0)  // teal
        case "deepseek":
            tint = NSColor(srgbRed: 0.42, green: 0.52, blue: 1.00, alpha: 1.0)  // blue
        case "grok", "vercel", "vercel-gateway":
            tint = NSColor(srgbRed: 0.78, green: 0.78, blue: 0.78, alpha: 1.0)  // near-white (in sRGB)
        case "cursor":
            tint = NSColor(srgbRed: 0.20, green: 0.78, blue: 0.82, alpha: 1.0)  // cyan
        case "kimi":
            tint = NSColor(srgbRed: 0.30, green: 0.65, blue: 0.95, alpha: 1.0)  // sky blue
        case "kiro":
            tint = NSColor(srgbRed: 0.55, green: 0.35, blue: 0.85, alpha: 1.0)  // purple
        case "bedrock":
            tint = NSColor(srgbRed: 1.00, green: 0.60, blue: 0.20, alpha: 1.0)  // amber
        case "mistral":
            tint = NSColor(srgbRed: 1.00, green: 0.55, blue: 0.00, alpha: 1.0)  // orange
        case "minimax":
            tint = NSColor(srgbRed: 0.91, green: 0.27, blue: 0.42, alpha: 1.0)  // red-pink
        case "zai":
            tint = NSColor(srgbRed: 0.35, green: 0.60, blue: 1.00, alpha: 1.0)  // azure
        case "ampcode":
            tint = NSColor(srgbRed: 0.95, green: 0.30, blue: 0.25, alpha: 1.0)  // hot red
        case "omp":
            tint = NSColor(srgbRed: 0.30, green: 0.85, blue: 0.55, alpha: 1.0)  // mint
        case "opencode", "opencode-go":
            tint = NSColor(srgbRed: 0.52, green: 0.36, blue: 1.00, alpha: 1.0)  // lavender
        case "alibaba":
            tint = NSColor(srgbRed: 1.00, green: 0.60, blue: 0.00, alpha: 1.0)  // orange
        default:
            tint = nil   // Claude / unknown = default terracotta
        }

        let bodyColor = tint ?? base

        if mood == .sleeping {
            let rgb = bodyColor.usingColorSpace(.sRGB) ?? bodyColor
            return NSColor(
                srgbRed: rgb.redComponent   * 0.82,
                green:  rgb.greenComponent  * 0.82,
                blue:   rgb.blueComponent   * 0.82,
                alpha:  1.0
            )
        }

        return bodyColor
    }

    // MARK: - Particle System

    private func spawnParticle(glyph: String, x: CGFloat, y: CGFloat,
                                vx: CGFloat, vy: CGFloat, size: CGFloat) {
        particles.append(Particle(x: x, y: y, vx: vx, vy: vy, alpha: 1.0, glyph: glyph, size: size))
    }

    private func drawParticles() {
        for p in particles {
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: p.size, weight: .bold),
                .foregroundColor: NSColor(white: 1.0, alpha: p.alpha)
            ]
            (p.glyph as NSString).draw(at: NSPoint(x: p.x - p.size * 0.25, y: p.y), withAttributes: attr)
        }
    }

    // MARK: - Helpers

    private func markActivity() {
        lastActivityTime = Date.timeIntervalSinceReferenceDate
    }

    /// Returns the most severe quota status across all gauges.
    private func worstStatus(from gauges: [TouchBarProviderGauge]) -> QuotaStatus {
        gauges.reduce(QuotaStatus.healthy) { worst, gauge in
            severity(of: gauge.status) > severity(of: worst) ? gauge.status : worst
        }
    }

    private func severity(of status: QuotaStatus) -> Int {
        switch status {
        case .healthy:  return 0
        case .warning:  return 1
        case .critical: return 2
        case .depleted: return 3
        }
    }

    // MARK: - Walk Frame (unchanged)

    private static func walkFrame(step: Int) -> [UInt8] {
        var buf = baseGrid
        for r in 14...16 {
            for c in 0..<20 {
                if buf[r * 20 + c] == 1 { buf[r * 20 + c] = 0 }
            }
        }
        let legX  = [5, 8, 12, 15]
        let swing = [
            [-1,  1, -1,  1],
            [ 0,  0,  0,  0],
            [ 1, -1,  1, -1],
            [ 0,  0,  0,  0]
        ]
        let lift = [
            [0, 1, 0, 1],
            [0, 0, 0, 0],
            [1, 0, 1, 0],
            [0, 0, 0, 0]
        ]
        let ph = step & 3
        for i in 0..<4 {
            let c = legX[i] + swing[ph][i]
            if c < 0 || c >= 20 { continue }
            let bottom = (lift[ph][i] == 1) ? 15 : 16
            for r in 14...bottom {
                buf[r * 20 + c] = 1
            }
        }
        return buf
    }

    // MARK: - Readout & Bars (unchanged from original)

    private func drawReadout() {
        guard !gauges.isEmpty else { return }

        let n = CGFloat(gauges.count)
        let totalReadoutW = readoutWidth
        let cellW = (totalReadoutW - cellGap * (n - 1)) / n
        let startX = readoutStartX

        for (i, gauge) in gauges.enumerated() {
            let cx = startX + CGFloat(i) * (cellW + cellGap)
            let icon = (i < cachedIcons.count) ? cachedIcons[i] : nil

            // Draw vertical separator | between cells
            if i > 0 {
                let sepX = cx - cellGap / 2.0
                NSColor(white: 1.0, alpha: 0.25).set()
                NSRect(x: sepX, y: 3.0, width: 1.0, height: 22.0).fill()
            }

            drawGaugeCell(gauge, icon: icon, x: cx, width: cellW)
        }
    }

    private func drawGaugeCell(_ gauge: TouchBarProviderGauge, icon: NSImage?, x: CGFloat, width: CGFloat) {
        let textY: CGFloat = 15.0
        let barY: CGFloat  = 3.0
        let barH: CGFloat  = 7.0

        let pct   = Int(gauge.percentUsed.rounded())
        let alarm = (pct >= 90)

        // Palette matching claude-usage-touchbar
        let ink: NSColor
        if alarm {
            ink = NSColor(srgbRed: 0.902, green: 0.208, blue: 0.180, alpha: 1.0) // #E6352E Alert Red
        } else if pct >= 50 {
            ink = NSColor(srgbRed: 0.949, green: 0.706, blue: 0.161, alpha: 1.0) // #F2B429 Warning Amber
        } else {
            ink = NSColor(srgbRed: 0.173, green: 0.533, blue: 0.945, alpha: 1.0) // #2C88F1 Healthy Blue
        }

        // 1. Draw Provider Icon
        var nameX = x
        let iconRect = NSRect(x: x, y: textY - 1.0, width: 14.0, height: 14.0)
        if let icon {
            NSGraphicsContext.saveGraphicsState()
            let clip = NSBezierPath(roundedRect: iconRect, xRadius: 3.0, yRadius: 3.0)
            clip.addClip()
            icon.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
            NSGraphicsContext.restoreGraphicsState()
            nameX += 18.0
        } else {
            let symName = ProviderVisualIdentityLookup.symbolIcon(for: gauge.providerId)
            if let sym = NSImage(systemSymbolName: symName, accessibilityDescription: nil) {
                let conf = NSImage.SymbolConfiguration(pointSize: 11, weight: .bold)
                if let configSym = sym.withSymbolConfiguration(conf) {
                    configSym.draw(in: iconRect, from: .zero, operation: .sourceOver, fraction: 1.0)
                    nameX += 18.0
                }
            }
        }

        // 2. Draw Provider Name
        let nameAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .bold),
            .foregroundColor: NSColor(white: 1.0, alpha: 0.85)
        ]
        (gauge.name as NSString).draw(at: NSPoint(x: nameX, y: textY), withAttributes: nameAttr)
        let nameW = (gauge.name as NSString).size(withAttributes: nameAttr).width

        // 3. Draw Reset Countdown Note
        if let reset = gauge.resetText, !reset.isEmpty {
            let noteAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 8, weight: .medium),
                .foregroundColor: NSColor(white: 1.0, alpha: 0.55)
            ]
            (reset as NSString).draw(at: NSPoint(x: nameX + nameW + 5.0, y: textY + 1.0), withAttributes: noteAttr)
        }

        // 4. Draw Percentage + Alarm Right-aligned
        let numStr = alarm ? "\(pct)% !" : "\(pct)%"
        let numAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: ink
        ]
        let numW = (numStr as NSString).size(withAttributes: numAttr).width
        (numStr as NSString).draw(at: NSPoint(x: x + width - numW, y: textY - 1.0), withAttributes: numAttr)

        // 5. Progress Bar Track (100% reference)
        let trackRect = NSRect(x: x, y: barY, width: width, height: barH)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 2.0, yRadius: 2.0)
        NSColor(white: 1.0, alpha: 0.32).set()
        trackPath.fill()

        // 6. Filled Bar
        let fillW = max(0, min(width, width * CGFloat(pct) / 100.0))
        if fillW > 0 {
            let fillRect = NSRect(x: x, y: barY, width: fillW, height: barH)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: 2.0, yRadius: 2.0)
            ink.set()
            fillPath.fill()
        }
    }

    private func loadProviderIcon(for providerId: String) -> NSImage? {
        let pid = providerId.lowercased()
        let home = FileManager.default.homeDirectoryForCurrentUser
        let userPath = home.appendingPathComponent(".claudebar/icons/\(pid).png").path
        if FileManager.default.fileExists(atPath: userPath), let img = NSImage(contentsOfFile: userPath) {
            return img
        }
        let assetName = ProviderVisualIdentityLookup.iconAssetName(for: pid)
        if let img = NSImage(named: assetName) {
            return img
        }
        return nil
    }
}
