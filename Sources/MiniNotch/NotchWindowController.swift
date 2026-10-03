import AppKit
import SwiftUI

/// Owns the panel for one screen and drives its presentation.
///
/// The panel frame always matches the resting shape (the notch or island,
/// plus any side wings), so it never covers more of the menu bar than it
/// draws. When the shape grows, the frame grows first and SwiftUI animates the
/// black shape inside it; when it shrinks, the frame shrinks only after the
/// animation has finished.
@MainActor
final class NotchWindowController {
    private static let chargeToastDuration: Duration = .seconds(3)
    /// Slight overshoot on growth feels alive; shrinking settles without bounce.
    private static let growAnimation = Animation.spring(response: 0.42, dampingFraction: 0.72)
    private static let shrinkAnimation = Animation.spring(response: 0.32, dampingFraction: 1)

    private let model = NotchViewModel()
    private let capture: CaptureDeviceMonitor
    private let settings: AppSettings
    private let launchAtLogin: LaunchAtLogin
    private let panel: NotchPanel
    private var geometry: NotchGeometry

    private var isHovering = false
    private var wantsMirror = false
    /// One-shot waits for the hover delay and the charging toast. Cancelled, never repeated.
    private var hoverDelayTask: Task<Void, Never>?
    private var chargeToastTask: Task<Void, Never>?
    /// Bumped on every transition so a stale shrink completion can't resize the panel.
    private var transitionID = 0

    init(
        screen: NSScreen,
        battery: BatteryMonitor,
        capture: CaptureDeviceMonitor,
        settings: AppSettings,
        launchAtLogin: LaunchAtLogin
    ) {
        self.capture = capture
        self.settings = settings
        self.launchAtLogin = launchAtLogin
        geometry = NotchGeometry(screen: screen, islandWidth: settings.islandSize.width)
        model.apply(geometry)
        panel = NotchPanel(contentRect: geometry.collapsedFrame())

        let container = HoverTrackingView(frame: .zero)
        let hostingView = NSHostingView(rootView: NotchView(
            model: model,
            battery: battery,
            capture: capture,
            settings: settings,
            launchAtLogin: launchAtLogin,
            onDropTargetChange: { [weak self] in self?.dropTargetDidChange($0) },
            onDrop: { [weak self] in self?.didDrop($0) },
            onMirrorChange: { [weak self] in self?.setMirroring($0) }
        ))
        // The controller owns the window size; SwiftUI must not resize it.
        hostingView.sizingOptions = []
        hostingView.safeAreaRegions = []
        container.embed(hostingView)
        container.onHoverChange = { [weak self] in self?.hoverDidChange($0) }
        panel.contentView = container

        model.wingWidth = restingWingWidth
        setPanelFrame(geometry.collapsedFrame(wingWidth: model.wingWidth))
        panel.orderFrontRegardless()
    }

    // MARK: - External events

    /// Re-applies geometry after the screen, its menu bar, or the island size changed.
    func update(screen: NSScreen) {
        let newGeometry = NotchGeometry(screen: screen, islandWidth: settings.islandSize.width)
        guard newGeometry != geometry else { return }
        geometry = newGeometry
        model.apply(newGeometry)
        setPanelFrame(model.isExpanded ? expandedFrame : newGeometry.collapsedFrame(wingWidth: model.wingWidth))
    }

    /// Removes the panel when its screen is disconnected.
    func close() {
        transitionID += 1
        hoverDelayTask?.cancel()
        chargeToastTask?.cancel()
        model.mirror?.stop()
        panel.orderOut(nil)
        panel.close()
    }

    func showChargeToast() {
        chargeToastTask?.cancel()
        model.isShowingChargeToast = true
        updatePresentation()
        chargeToastTask = Task { [weak self] in
            try? await Task.sleep(for: Self.chargeToastDuration)
            guard !Task.isCancelled, let self else { return }
            self.model.isShowingChargeToast = false
            self.updatePresentation()
        }
    }

    func captureStateDidChange() {
        updatePresentation()
    }

    // MARK: - Panel events

    private func hoverDidChange(_ hovering: Bool) {
        hoverDelayTask?.cancel()
        hoverDelayTask = nil

        let delay = settings.hoverDelay.duration
        guard hovering, delay > .zero, !model.isExpanded else {
            isHovering = hovering
            updatePresentation()
            return
        }
        // Expand only if the pointer is still inside once the delay has passed.
        hoverDelayTask = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled, let self else { return }
            self.isHovering = true
            self.updatePresentation()
        }
    }

    private func dropTargetDidChange(_ targeted: Bool) {
        model.isDropTargeted = targeted
        if !targeted {
            // Tracking areas may not report exits during a drag session, so
            // re-derive the hover state from the actual pointer position.
            isHovering = panel.frame.contains(NSEvent.mouseLocation)
        }
        updatePresentation()
    }

    private func didDrop(_ urls: [URL]) {
        model.isDropTargeted = false
        isHovering = false
        updatePresentation()
        // Let the drag session finish before presenting the sharing sheet.
        DispatchQueue.main.async {
            AirDropService.share(urls)
        }
    }

    private func setMirroring(_ on: Bool) {
        guard on != wantsMirror else { return }
        wantsMirror = on
        if on {
            let mirror = model.mirror ?? CameraMirror()
            model.mirror = mirror
            mirror.start()
        } else {
            model.mirror?.stop()
        }
        updatePresentation()
    }

    // MARK: - Presentation

    private var expandedFrame: NSRect {
        wantsMirror ? geometry.mirrorFrame : geometry.expandedFrame
    }

    private var restingWingWidth: CGFloat {
        if model.isShowingChargeToast {
            return NotchGeometry.chargeToastWingWidth
        }
        if capture.isCameraInUse || capture.isMicrophoneInUse {
            return NotchGeometry.captureWingWidth
        }
        return 0
    }

    /// Moves the panel to the state implied by hover, drag, mirror, toast and capture inputs.
    private func updatePresentation() {
        let expand = isHovering || model.isDropTargeted
        if !expand && wantsMirror {
            // Leaving the panel closes the mirror and turns the camera off.
            wantsMirror = false
            model.mirror?.stop()
        }
        let wingWidth = restingWingWidth
        guard expand != model.isExpanded || wingWidth != model.wingWidth || wantsMirror != model.isMirroring else {
            return
        }

        let target = expand ? expandedFrame : geometry.collapsedFrame(wingWidth: wingWidth)
        // States are nested rectangles centered on the notch (collapsed ⊂ expanded ⊂ mirror),
        // so "not larger" means "smaller or equal".
        let grows = target.width >= panel.frame.width && target.height >= panel.frame.height
        if expand && !model.isExpanded {
            launchAtLogin.refresh()
        }

        transitionID += 1
        let id = transitionID
        if grows {
            setPanelFrame(target)
        }
        withAnimation(grows ? Self.growAnimation : Self.shrinkAnimation, completionCriteria: .removed) {
            model.isExpanded = expand
            model.wingWidth = wingWidth
            model.isMirroring = wantsMirror
        } completion: { [weak self] in
            guard let self, !grows, id == self.transitionID else { return }
            self.setPanelFrame(target)
        }
    }

    /// Resizes the panel and lays SwiftUI out for the new size immediately.
    ///
    /// Without the synchronous layout, NSHostingView applies the new bounds in
    /// its next pass, which lands inside the expand animation transaction: the
    /// shape's re-centering then animates too and it visibly slides sideways.
    private func setPanelFrame(_ frame: NSRect) {
        panel.setFrame(frame, display: false)
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
    }
}
