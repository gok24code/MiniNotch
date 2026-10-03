import SwiftUI

/// Widgets shown below the notch while the panel is expanded.
struct ExpandedNotchContent: View {
    let battery: BatteryMonitor
    let isDropTargeted: Bool
    let onOpenMirror: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if let snapshot = battery.snapshot {
                BatteryView(snapshot: snapshot)
            }
            DropZoneView(isTargeted: isDropTargeted)
            MirrorButton(action: onOpenMirror)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
        .padding(.bottom, 12)
        .foregroundStyle(.white)
    }
}

/// Opens the camera mirror.
private struct MirrorButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "camera.fill")
                .font(.system(size: 18))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: 52)
                .frame(maxHeight: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.1))
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open mirror")
    }
}

extension AnyTransition {
    /// Content fades in from a soft blur slightly after the shape starts growing,
    /// and fades out quickly on collapse so it never looks squeezed.
    static var notchContent: AnyTransition {
        .asymmetric(
            insertion: .modifier(
                active: NotchContentReveal(progress: 0),
                identity: NotchContentReveal(progress: 1)
            )
            .animation(.smooth(duration: 0.32).delay(0.06)),
            removal: .opacity.animation(.easeOut(duration: 0.12))
        )
    }
}

private struct NotchContentReveal: ViewModifier {
    let progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .blur(radius: (1 - progress) * 6)
            .scaleEffect(0.92 + 0.08 * progress, anchor: .top)
    }
}
