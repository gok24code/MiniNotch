import AppKit

/// Where the panel sits on a screen, and the frames it uses in its collapsed
/// and expanded states. Notched displays get a panel flush with the hardware
/// notch; other displays get a floating island inside the menu bar.
struct NotchGeometry: Equatable {
    enum Style: Equatable {
        case notch, island
    }

    /// Side wing width while the charging toast is shown.
    static let chargeToastWingWidth: CGFloat = 52
    /// Side wing width while a camera or microphone is in use.
    static let captureWingWidth: CGFloat = 22
    /// Gap between the island and the top screen edge (and the menu bar bottom).
    static let islandGap: CGFloat = 4
    /// Minimum width of the expanded panel.
    static let expandedWidth: CGFloat = 400
    /// Height of the content area shown below the notch when expanded.
    static let expandedContentHeight: CGFloat = 84
    /// Height of the camera preview area in mirror mode.
    static let mirrorContentHeight: CGFloat = 220
    /// Concave ear radius of the expanded notch; the ears extend past the body on both sides.
    static let notchEarRadius: CGFloat = 10

    let screenFrame: NSRect
    let style: Style
    /// Size of the shape when collapsed: the hardware notch, or the island pill.
    let collapsedSize: CGSize
    /// Distance from the top screen edge to the top of the shape.
    let topInset: CGFloat

    init(screen: NSScreen, islandWidth: CGFloat) {
        screenFrame = screen.frame

        let notchHeight = screen.safeAreaInsets.top
        if notchHeight > 0,
           let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            // The notch is the gap between the two unobscured menu bar areas.
            style = .notch
            collapsedSize = CGSize(width: screen.frame.width - left.width - right.width, height: notchHeight)
            topInset = 0
        } else {
            // Center the island vertically in the menu bar. Fall back to the system
            // thickness when the menu bar is auto-hidden and visibleFrame ignores it.
            let measured = screen.frame.maxY - screen.visibleFrame.maxY
            let menuBarHeight = measured > 0 ? measured : NSStatusBar.system.thickness
            let height = max(menuBarHeight - 2 * Self.islandGap, 20)
            style = .island
            collapsedSize = CGSize(width: islandWidth, height: height)
            topInset = ((menuBarHeight - height) / 2).rounded()
        }
    }

    /// Space above the expanded content: clears the camera housing on a notch.
    var contentTopPadding: CGFloat {
        switch style {
        case .notch: collapsedSize.height
        case .island: 8
        }
    }

    /// Ear radius while expanded. Islands float, so they have no ears.
    var expandedEarRadius: CGFloat {
        style == .notch ? Self.notchEarRadius : 0
    }

    var expandedSize: CGSize {
        CGSize(
            width: max(Self.expandedWidth, collapsedSize.width + 120),
            height: contentTopPadding + Self.expandedContentHeight
        )
    }

    var mirrorSize: CGSize {
        CGSize(width: expandedSize.width, height: contentTopPadding + Self.mirrorContentHeight)
    }

    var mirrorFrame: NSRect {
        frame(for: CGSize(width: mirrorSize.width + 2 * expandedEarRadius, height: mirrorSize.height))
    }

    /// The collapsed shape plus `wingWidth` on each side.
    func collapsedFrame(wingWidth: CGFloat = 0) -> NSRect {
        frame(for: CGSize(width: collapsedSize.width + 2 * wingWidth, height: collapsedSize.height))
    }

    /// Exactly the expanded shape, ears included, so no transparent area catches clicks.
    var expandedFrame: NSRect {
        frame(for: CGSize(width: expandedSize.width + 2 * expandedEarRadius, height: expandedSize.height))
    }

    /// A frame of `size`, horizontally centered, `topInset` below the top screen edge.
    private func frame(for size: CGSize) -> NSRect {
        NSRect(
            x: (screenFrame.midX - size.width / 2).rounded(),
            y: screenFrame.maxY - topInset - size.height,
            width: size.width,
            height: size.height
        )
    }
}
