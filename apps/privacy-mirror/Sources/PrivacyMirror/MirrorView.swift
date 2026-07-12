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
        displayLayer.flushAndRemoveImage()
        statusLabel.stringValue = message
        statusLabel.isHidden = false
    }

    func blank() {
        displayLayer.flushAndRemoveImage()
        statusLabel.stringValue = "Reclassifying windows…"
        statusLabel.isHidden = false
    }

    func updatePlaceholders(
        regions: [CGRect],
        displayFrame: CGRect,
        style: PlaceholderStyle
    ) {
        placeholderViews.forEach { $0.removeFromSuperview() }
        placeholderViews.removeAll()

        guard displayFrame.width > 0, displayFrame.height > 0 else { return }

        let scale = min(bounds.width / displayFrame.width, bounds.height / displayFrame.height)
        let renderedSize = CGSize(
            width: displayFrame.width * scale,
            height: displayFrame.height * scale
        )
        let offset = CGPoint(
            x: (bounds.width - renderedSize.width) / 2,
            y: (bounds.height - renderedSize.height) / 2
        )

        for region in regions {
            let clipped = region.intersection(displayFrame)
            guard !clipped.isNull, clipped.width > 1, clipped.height > 1 else { continue }

            let frame = CGRect(
                x: offset.x + (clipped.minX - displayFrame.minX) * scale,
                y: offset.y + (clipped.minY - displayFrame.minY) * scale,
                width: clipped.width * scale,
                height: clipped.height * scale
            )
            let placeholder = makePlaceholder(style: style, frame: frame)
            addSubview(placeholder)
            placeholderViews.append(placeholder)
        }
    }

    private func makePlaceholder(style: PlaceholderStyle, frame: CGRect) -> NSView {
        switch style {
        case .blur:
            let view = NSVisualEffectView(frame: frame)
            view.material = .hudWindow
            view.blendingMode = .withinWindow
            view.state = .active
            view.wantsLayer = true
            view.layer?.cornerRadius = 8
            view.layer?.masksToBounds = true
            return view
        case .solid:
            let view = NSView(frame: frame)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            view.layer?.cornerRadius = 8
            return view
        }
    }
}
