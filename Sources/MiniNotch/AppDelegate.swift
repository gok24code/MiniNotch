import AppKit

/// Owns the screen coordinator and forwards display configuration changes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var screens: ScreenCoordinator?

    func applicationDidFinishLaunching(_ notification: Notification) {
        screens = ScreenCoordinator()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        screens?.shutdown()
    }

    @objc private func screenParametersDidChange(_ notification: Notification) {
        screens?.syncWithScreens()
    }
}
