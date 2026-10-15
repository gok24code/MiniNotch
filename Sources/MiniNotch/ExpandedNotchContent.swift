import SwiftUI

/// Widgets shown below the notch while the panel is expanded.
struct ExpandedNotchContent: View {
    let battery: BatteryMonitor
    let awake: AwakeKeeper
    let isDropTargeted: Bool
    let onOpenMirror: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if let snapshot = battery.snapshot {
                BatteryView(snapshot: snapshot)
            }
            DropZoneView(isTargeted: isDropTargeted)
            AwakeToggle(awake: awake)
            MirrorButton(action: onOpenMirror)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 10)
        .foregroundStyle(.white)
    }
}

/// Always Awake switch; turning it on reveals the list of apps being waited for.
private struct AwakeToggle: View {
    let awake: AwakeKeeper

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: awake.isEnabled ? "cup.and.saucer.fill" : "cup.and.saucer")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(awake.isEnabled ? 1 : 0.85))
            Toggle("Always Awake", isOn: Binding(
                get: { awake.isEnabled },
                set: { awake.setEnabled($0) }
            ))
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.mini)
        }
        .frame(width: 44)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(awake.isEnabled ? 0.18 : 0.1))
        )
        .help("Always Awake")
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
                .frame(width: 44)
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
