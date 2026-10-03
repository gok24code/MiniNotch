import AppKit
import SwiftUI

/// Right-click menu: preferences, launch-at-login toggle and quit.
struct NotchContextMenu: View {
    @Bindable var settings: AppSettings
    let launchAtLogin: LaunchAtLogin

    var body: some View {
        Picker("Hover Delay", selection: $settings.hoverDelay) {
            ForEach(AppSettings.HoverDelay.allCases) { delay in
                Text(delay.title).tag(delay)
            }
        }
        Picker("Island Size", selection: $settings.islandSize) {
            ForEach(AppSettings.IslandSize.allCases) { size in
                Text(size.title).tag(size)
            }
        }
        Divider()
        Toggle("Launch at Login", isOn: Binding(
            get: { launchAtLogin.isEnabled },
            set: { launchAtLogin.setEnabled($0) }
        ))
        Divider()
        Button("Quit MiniNotch") {
            NSApp.terminate(nil)
        }
    }
}
