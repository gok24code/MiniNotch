import SwiftUI

/// AirDrop target. Highlights while a file drag is over the notch.
struct DropZoneView: View {
    let isTargeted: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)

        HStack(spacing: 8) {
            Image(systemName: "dot.radiowaves.left.and.right")
                .font(.system(size: 18, weight: .medium))
                .scaleEffect(isTargeted ? 1.15 : 1)
            Text(isTargeted ? "Release to AirDrop" : "Drop files to AirDrop")
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(isTargeted ? Color.accentColor : .white.opacity(0.7))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
