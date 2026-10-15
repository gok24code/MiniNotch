import CoreGraphics
import Observation

/// UI state shared between the window controller and the SwiftUI views.
@MainActor
@Observable
final class NotchViewModel {
    var isExpanded = false
    var isDropTargeted = false
    /// Width added on each side of the collapsed shape for the charging toast or capture dots.
    var wingWidth: CGFloat = 0
    var isShowingChargeToast = false
    /// Created on first use so AVFoundation stays idle until the mirror is opened.
    var mirror: CameraMirror?
    var isMirroring = false
    /// Whether the expanded panel is tall enough to show the Always Awake task list.
    var isShowingAwakeList = false
    /// Height added below the expanded content for the task list; follows the number of apps.
    var awakeListHeight: CGFloat = 0

    var style: NotchGeometry.Style = .notch
    var collapsedSize: CGSize = .zero
    var expandedSize: CGSize = .zero
    var mirrorSize: CGSize = .zero
    var contentTopPadding: CGFloat = 0
    var expandedEarRadius: CGFloat = 0

    func apply(_ geometry: NotchGeometry) {
        style = geometry.style
        collapsedSize = geometry.collapsedSize
        expandedSize = geometry.expandedSize
        mirrorSize = geometry.mirrorSize
        contentTopPadding = geometry.contentTopPadding
        expandedEarRadius = geometry.expandedEarRadius
    }
}
