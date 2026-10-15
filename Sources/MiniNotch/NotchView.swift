import SwiftUI

/// Root view: a black shape that morphs between its collapsed form (notch or
/// island pill) and the expanded panel.
struct NotchView: View {
    private static let expandedCornerRadius: CGFloat = 22
    private static let collapsedNotchCornerRadius: CGFloat = 8

    let model: NotchViewModel
    let battery: BatteryMonitor
    let capture: CaptureDeviceMonitor
    let awake: AwakeKeeper
    let settings: AppSettings
    let launchAtLogin: LaunchAtLogin
    let onDropTargetChange: (Bool) -> Void
    let onDrop: ([URL]) -> Void
    let onMirrorChange: (Bool) -> Void

    var body: some View {
        let isExpanded = model.isExpanded
        let size = isExpanded
            ? (model.isMirroring
                ? model.mirrorSize
                : CGSize(width: model.expandedSize.width, height: model.expandedSize.height + model.awakeListHeight))
            : CGSize(width: model.collapsedSize.width + 2 * model.wingWidth, height: model.collapsedSize.height)
        let shape = shape(isExpanded: isExpanded)
        let ear = shape.earRadius

        ZStack(alignment: .top) {
            shape.fill(.black)

            // Inserted only while expanded, so the collapsed hierarchy is just one shape.
            if isExpanded, model.isMirroring, let mirror = model.mirror {
                MirrorView(mirror: mirror, onClose: { onMirrorChange(false) })
                    .padding(.top, model.contentTopPadding)
                    .padding(.horizontal, ear)
                    .transition(.notchContent)
            } else if isExpanded {
                VStack(spacing: 0) {
                    ExpandedNotchContent(
                        battery: battery,
                        awake: awake,
                        isDropTargeted: model.isDropTargeted,
                        onOpenMirror: { onMirrorChange(true) }
                    )
                    .frame(height: NotchGeometry.expandedContentHeight)
                    if model.isShowingAwakeList {
                        AwakeListView(awake: awake)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.top, model.contentTopPadding)
                .padding(.horizontal, ear)
                .transition(.notchContent)
            } else if model.wingWidth > 0 {
                CollapsedWingsView(
                    wingWidth: model.wingWidth,
                    isShowingChargeToast: model.isShowingChargeToast,
                    battery: battery,
                    capture: capture
                )
                .frame(height: model.collapsedSize.height)
                .transition(.opacity)
            }
        }
        .frame(width: size.width + 2 * ear, height: size.height)
        .clipShape(shape)
        .contentShape(shape)
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter(\.isFileURL)
            onDrop(files)
            return !files.isEmpty
        } isTargeted: { targeted in
            onDropTargetChange(targeted)
        }
        .contextMenu {
            NotchContextMenu(settings: settings, launchAtLogin: launchAtLogin, awake: awake)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .ignoresSafeArea()
    }

    private func shape(isExpanded: Bool) -> NotchShape {
        switch model.style {
        case .notch:
            return NotchShape(
                // Zero when collapsed so the shape matches the hardware notch exactly.
                earRadius: isExpanded ? model.expandedEarRadius : 0,
                topCornerRadius: 0,
                bottomCornerRadius: isExpanded ? Self.expandedCornerRadius : Self.collapsedNotchCornerRadius
            )
        case .island:
            // A capsule when collapsed, a rounded card when expanded.
            let radius = isExpanded ? Self.expandedCornerRadius : model.collapsedSize.height / 2
            return NotchShape(earRadius: 0, topCornerRadius: radius, bottomCornerRadius: radius)
        }
    }
}
