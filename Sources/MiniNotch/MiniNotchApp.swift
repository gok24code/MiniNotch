import AppKit

/// Entry point. A plain AppKit run loop keeps the app tiny; SwiftUI is only
/// used inside the notch panel.
@main
enum MiniNotchApp {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        // No Dock icon or menu bar (Info.plist also sets LSUIElement for the bundle).
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
