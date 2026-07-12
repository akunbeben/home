import AppKit
import AVFoundation
import PrivacyMirrorCore

@MainActor
final class MirrorView: NSView {
    private let displayLayer = AVSampleBufferDisplayLayer()
    private let statusLabel = NSTextField(labelWithString: "Starting Privacy Mirror…")
    private var placeholderViews: [NSView] = []

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.black.cgColor

        displayLayer.videoGravity = .resizeAspect
        layer?.addSublayer(displayLayer)

        statusLabel.textColor = .white
        statusLabel.font = .systemFont(ofSize: 18, weight: .medium)
        statusLabel.alignment = .center
        addSubview(statusLabel)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layout() {
        super.layout()
        displayLayer.frame = bounds
        statusLabel.frame = NSRect(x: 24, y: bounds.midY - 12, width: bounds.width - 48, height: 24)
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        statusLabel.isHidden = true
        if displayLayer.status == .failed {
            displayLayer.flush()
        }
        displayLayer.enqueue(sampleBuffer)
    }

    func showError(_ message: String) {
        removePlaceholders()
        displayLayer.flushAndRemoveImage()
        statusLabel.stringValue = message
        statusLabel.isHidden = false
    }

    func blank() {
        removePlaceholders()
        displayLayer.flushAndRemoveImage()
        statusLabel.stringValue = "Reclassifying windows…"
        statusLabel.isHidden = false
    }

    func updatePlaceholders(
        regions: [CGRect],
        displayFrame: CGRect,
        style: PlaceholderStyle
    ) {
        removePlaceholders()

        for frame in PlaceholderLayout.frames(
            for: regions,
            displayFrame: displayFrame,
            viewBounds: bounds
        ) {
            let placeholder = makePlaceholder(style: style, frame: frame)
            addSubview(placeholder)
            placeholderViews.append(placeholder)
        }
    }

    private func makePlaceholder(style: PlaceholderStyle, frame: CGRect) -> NSView {
        PrivacyPlaceholderView(frame: frame, style: style)
    }

    private func removePlaceholders() {
        placeholderViews.forEach { $0.removeFromSuperview() }
        placeholderViews.removeAll()
    }
}

private final class PrivacyPlaceholderView: NSView {
    private let style: PlaceholderStyle

    init(frame frameRect: NSRect, style: PlaceholderStyle) {
        self.style = style
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 14
        layer?.masksToBounds = true
        layer?.shouldRasterize = true
        layer?.rasterizationScale = NSScreen.main?.backingScaleFactor ?? 2
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isOpaque: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let rect = bounds.insetBy(dx: 0.5, dy: 0.5)
        let radius = min(14, min(rect.width, rect.height) / 7)
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)

        drawBackground(in: path)
        drawPattern(clippedTo: path, in: rect)
        drawBorder(path)
        drawContent(in: rect)
    }

    private func drawBackground(in path: NSBezierPath) {
        let colors: [NSColor]
        switch style {
        case .blur:
            colors = [
                NSColor(calibratedRed: 0.10, green: 0.12, blue: 0.18, alpha: 0.98),
                NSColor(calibratedRed: 0.04, green: 0.05, blue: 0.08, alpha: 0.98),
            ]
        case .solid:
            colors = [
                NSColor(calibratedWhite: 0.055, alpha: 1),
                NSColor(calibratedWhite: 0.025, alpha: 1),
            ]
        }

        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        NSGradient(colors: colors)?.draw(in: path.bounds, angle: -90)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawPattern(clippedTo path: NSBezierPath, in rect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        path.addClip()

        NSColor(calibratedWhite: 1, alpha: style == .blur ? 0.055 : 0.035).setStroke()
        let stripe = NSBezierPath()
        stripe.lineWidth = 1

        var x = rect.minX - rect.height
        while x < rect.maxX {
            stripe.move(to: NSPoint(x: x, y: rect.maxY))
            stripe.line(to: NSPoint(x: x + rect.height, y: rect.minY))
            x += 22
        }
        stripe.stroke()

        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawBorder(_ path: NSBezierPath) {
        NSColor(calibratedRed: 0.36, green: 0.47, blue: 0.95, alpha: 0.55).setStroke()
        path.lineWidth = 1
        path.stroke()

        let inner = NSBezierPath(roundedRect: bounds.insetBy(dx: 2.5, dy: 2.5), xRadius: 11, yRadius: 11)
        NSColor(calibratedWhite: 1, alpha: 0.08).setStroke()
        inner.lineWidth = 1
        inner.stroke()
    }

    private func drawContent(in rect: NSRect) {
        if rect.width < 120 || rect.height < 72 {
            drawSmallLabel(in: rect)
            return
        }

        let centerX = rect.midX
        let totalHeight: CGFloat = rect.height >= 150 ? 104 : 76
        let top = rect.midY - totalHeight / 2
        let iconSize: CGFloat = rect.height >= 150 ? 42 : 30
        let iconRect = NSRect(
            x: centerX - iconSize / 2,
            y: top,
            width: iconSize,
            height: iconSize
        )

        drawIcon(in: iconRect)

        let title = NSAttributedString(
            string: "Private workspace",
            attributes: [
                .foregroundColor: NSColor(calibratedWhite: 0.96, alpha: 1),
                .font: NSFont.systemFont(ofSize: rect.height >= 150 ? 20 : 15, weight: .semibold),
            ]
        )
        title.draw(centeredAtY: iconRect.maxY + 16, in: rect)

        guard rect.width >= 220, rect.height >= 120 else { return }
        let subtitle = NSAttributedString(
            string: "Hidden from screen share",
            attributes: [
                .foregroundColor: NSColor(calibratedWhite: 0.82, alpha: 0.76),
                .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            ]
        )
        subtitle.draw(centeredAtY: iconRect.maxY + 44, in: rect)
    }

    private func drawSmallLabel(in rect: NSRect) {
        let label = NSAttributedString(
            string: "Hidden",
            attributes: [
                .foregroundColor: NSColor(calibratedWhite: 0.9, alpha: 0.9),
                .font: NSFont.systemFont(ofSize: min(12, max(9, rect.height / 4)), weight: .semibold),
            ]
        )
        label.draw(centeredAtY: rect.midY - label.size().height / 2, in: rect)
    }

    private func drawIcon(in rect: NSRect) {
        let circle = NSBezierPath(ovalIn: rect)
        NSColor(calibratedWhite: 1, alpha: 0.12).setFill()
        circle.fill()
        NSColor(calibratedWhite: 1, alpha: 0.20).setStroke()
        circle.lineWidth = 1
        circle.stroke()

        guard let image = NSImage(systemSymbolName: "lock.fill", accessibilityDescription: nil) else {
            return
        }

        let symbolSize = rect.width * 0.45
        let symbolRect = NSRect(
            x: rect.midX - symbolSize / 2,
            y: rect.midY - symbolSize / 2,
            width: symbolSize,
            height: symbolSize
        )

        NSColor(calibratedWhite: 0.96, alpha: 0.95).set()
        image.draw(in: symbolRect, from: .zero, operation: .sourceOver, fraction: 1)
    }
}

private extension NSAttributedString {
    func draw(centeredAtY y: CGFloat, in rect: NSRect) {
        let size = size()
        draw(at: NSPoint(x: rect.midX - size.width / 2, y: y))
    }
}
