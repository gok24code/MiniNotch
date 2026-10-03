import AppKit

/// Keeps one notch panel per connected screen: the notch style on notched
/// displays, a floating island everywhere else. Monitors and settings are
/// shared, so extra screens add no extra observers.
@MainActor
final class ScreenCoordinator {
    private let battery = BatteryMonitor()
    private let capture = CaptureDeviceMonitor()
    private let settings = AppSettings()
    private let launchAtLogin = LaunchAtLogin()
    private var controllers: [CGDirectDisplayID: NotchWindowController] = [:]

    init() {
        battery.onPowerConnected = { [weak self] in
            self?.controllers.values.forEach { $0.showChargeToast() }
        }
        capture.onChange = { [weak self] in
            self?.controllers.values.forEach { $0.captureStateDidChange() }
        }
        settings.onIslandSizeChange = { [weak self] in
            self?.syncWithScreens()
        }
        syncWithScreens()
    }

    /// Adds panels for new screens, updates existing ones and removes panels of disconnected screens.
    func syncWithScreens() {
        var connected = Set<CGDirectDisplayID>()

        for screen in NSScreen.screens {
            guard let id = screen.displayID else { continue }
            connected.insert(id)
            if let controller = controllers[id] {
                controller.update(screen: screen)
            } else {
                controllers[id] = NotchWindowController(
                    screen: screen,
                    battery: battery,
                    capture: capture,
                    settings: settings,
                    launchAtLogin: launchAtLogin
                )
            }
        }

        for (id, controller) in controllers where !connected.contains(id) {
            controller.close()
            controllers[id] = nil
        }
    }
}

private extension NSScreen {
    /// Stable identifier of the display; NSScreen instances are recreated on configuration changes.
    var displayID: CGDirectDisplayID? {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
    }
}
