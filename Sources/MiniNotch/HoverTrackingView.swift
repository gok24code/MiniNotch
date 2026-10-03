import AppKit

/// Container view that reports mouse enter/exit for its own window only.
/// The tracking area follows the view's bounds, so it is always exactly the
/// panel frame; no global event monitor is involved.
final class HoverTrackingView: NSView {
    var onHoverChange: ((Bool) -> Void)?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        addTrackingArea(NSTrackingArea(
            rect: .zero,
            // .activeAlways: the panel is never key, so other modes would never fire.
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// Embeds `content` so it always fills this view.
    func embed(_ content: NSView) {
        content.frame = bounds
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    override func mouseEntered(with event: NSEvent) {
        onHoverChange?(true)
    }

    override func mouseExited(with event: NSEvent) {
        onHoverChange?(false)
    }
}
