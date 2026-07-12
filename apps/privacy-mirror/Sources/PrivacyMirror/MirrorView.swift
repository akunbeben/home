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

    private func removePlaceholders() {
        placeholderViews.forEach { $0.removeFromSuperview() }
        placeholderViews.removeAll()
    }
}
