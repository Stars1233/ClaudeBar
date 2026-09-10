import AppKit
import CoreGraphics
import Domain
import Infrastructure

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

// MARK: - TouchBarQuotaView

/// Lightweight, battery-efficient Touch Bar view displaying live AI provider usage gauges.
/// Features centered positioning, color-coded progress bars, and direct tap-to-open interaction.
@MainActor
public final class TouchBarQuotaView: NSView {
    public static let sceneW: CGFloat = 600.0
    public static let sceneH: CGFloat = 30.0

    // MARK: - Properties

    public var gauges: [TouchBarProviderGauge] = [] {
        didSet {
            if gauges != oldValue {
                cachedIcons = gauges.map { loadProviderIcon(for: $0.providerId) }
                needsDisplay = true
            }
        }
    }

    public var sessionActive: Bool = false {
        didSet {
            if sessionActive != oldValue {
                needsDisplay = true
            }
        }
    }

    private var cachedIcons: [NSImage?] = []
    private var isRefreshing: Bool = false

    // MARK: - Layout Metrics

    private let cellGap: CGFloat = 16.0

    // MARK: - Init

    public override init(frame: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.sceneW, height: Self.sceneH))
        self.allowedTouchTypes = [.direct]
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override var isFlipped: Bool { false }
    public override var acceptsFirstResponder: Bool { true }

    // MARK: - Refresh Feedback

    public func triggerRefreshPulse() {
        isRefreshing = true
        needsDisplay = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            self?.isRefreshing = false
            self?.needsDisplay = true
        }
    }

    // MARK: - Touch Interaction

    public override func touchesBegan(with event: NSEvent) {
        guard let _ = event.touches(matching: .any, in: self).first else { return }
        // Tapping anywhere on the Touch Bar quota view opens ClaudeBar
        if let url = URL(string: "claudebar://open") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Drawing

    public override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill()

        guard !gauges.isEmpty else { return }

        let n = CGFloat(gauges.count)
        let totalWidth: CGFloat
        let cellW: CGFloat

        if n == 1 {
            cellW = 240.0
            totalWidth = cellW
        } else if n == 2 {
            cellW = 210.0
            totalWidth = n * cellW + (n - 1) * cellGap
        } else {
            let maxTotalW: CGFloat = min(560.0, bounds.width - 24.0)
            cellW = max(120.0, (maxTotalW - (n - 1) * cellGap) / n)
            totalWidth = n * cellW + (n - 1) * cellGap
        }

        // Center the gauges horizontally on the Touch Bar
        let startX = max(10.0, (bounds.width - totalWidth) / 2.0)

        for (i, gauge) in gauges.enumerated() {
            let cx = startX + CGFloat(i) * (cellW + cellGap)
            let icon = (i < cachedIcons.count) ? cachedIcons[i] : nil

            // Draw vertical separator between multiple cells
            if i > 0 {
                let sepX = cx - cellGap / 2.0
                NSColor(white: 1.0, alpha: 0.20).set()
                NSRect(x: sepX, y: 4.0, width: 1.0, height: 22.0).fill()
            }

            drawGaugeCell(gauge, icon: icon, x: cx, width: cellW)
        }
    }

    private func drawGaugeCell(_ gauge: TouchBarProviderGauge, icon: NSImage?, x: CGFloat, width: CGFloat) {
        let textY: CGFloat = 15.0
        let barY: CGFloat  = 3.0
        let barH: CGFloat  = 7.0

        let pct = Int(gauge.percentUsed.rounded())
        let alarm = (pct >= 90)

        let ink: NSColor
        if alarm {
            ink = NSColor(srgbRed: 0.902, green: 0.208, blue: 0.180, alpha: 1.0) // Alert Red
        } else if pct >= 50 {
            ink = NSColor(srgbRed: 0.949, green: 0.706, blue: 0.161, alpha: 1.0) // Warning Amber
        } else {
            ink = NSColor(srgbRed: 0.173, green: 0.533, blue: 0.945, alpha: 1.0) // Healthy Blue
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
            .foregroundColor: NSColor(white: 1.0, alpha: 0.90)
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
        var numStr = "\(pct)%"
        if alarm {
            numStr += " !"
        }
        if isRefreshing {
            numStr = "🔄 " + numStr
        }

        let numAttr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: ink
        ]
        let numW = (numStr as NSString).size(withAttributes: numAttr).width
        (numStr as NSString).draw(at: NSPoint(x: x + width - numW, y: textY - 1.0), withAttributes: numAttr)

        // 5. Progress Bar Track (100% reference)
        let trackRect = NSRect(x: x, y: barY, width: width, height: barH)
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: 2.0, yRadius: 2.0)
        NSColor(white: 1.0, alpha: 0.30).set()
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
