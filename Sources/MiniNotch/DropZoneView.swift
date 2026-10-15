import AppKit
import SwiftUI

/// AirDrop target. Highlights while a file drag is over the notch.
struct DropZoneView: View {
    let isTargeted: Bool

    /// The system AirDrop icon; SF Symbols has no public AirDrop glyph.
    private static let airDropIcon: NSImage? = {
        let path = "/System/Library/CoreServices/Finder.app/Contents/Applications/AirDrop.app"
        guard FileManager.default.fileExists(atPath: path) else { return nil }
        return NSWorkspace.shared.icon(forFile: path)
    }()

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        Group {
            if let icon = Self.airDropIcon {
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 28, height: 28)
            } else {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 18, weight: .medium))
            }
        }
        .scaleEffect(isTargeted ? 1.15 : 1)
        .accessibilityLabel("Drop files to AirDrop")
        .foregroundStyle(isTargeted ? Color.accentColor : .white.opacity(0.7))
        .frame(width: 56)
        .frame(maxHeight: .infinity)
        .background(shape.fill(Color.accentColor.opacity(isTargeted ? 0.22 : 0)))
        .overlay(
            shape.strokeBorder(
                isTargeted ? Color.accentColor : .white.opacity(0.25),
                style: StrokeStyle(lineWidth: isTargeted ? 2 : 1, dash: isTargeted ? [] : [5, 4])
            )
        )
        .scaleEffect(isTargeted ? 1.02 : 1)
        // One-shot spring per state change; nothing animates while idle.
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isTargeted)
    }
}
