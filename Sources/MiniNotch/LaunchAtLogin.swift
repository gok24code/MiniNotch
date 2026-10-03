import Foundation
import Observation
import ServiceManagement

/// Thin wrapper around `SMAppService.mainApp`. Only works from the bundled .app.
@MainActor
@Observable
final class LaunchAtLogin {
    private(set) var isEnabled = false

    init() {
        refresh()
    }

    /// Re-reads the status; the user can change it in System Settings at any time.
    func refresh() {
        let enabled = SMAppService.mainApp.status == .enabled
        if enabled != isEnabled {
            isEnabled = enabled
        }
    }

    func setEnabled(_ enabled: Bool) {
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            NSLog("MiniNotch: launch at login change failed: \(error.localizedDescription)")
        }
        if service.status == .requiresApproval {
            SMAppService.openSystemSettingsLoginItems()
        }
        refresh()
    }
}
