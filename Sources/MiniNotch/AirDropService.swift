import AppKit

/// Hands dropped files to the system AirDrop sharing sheet.
@MainActor
enum AirDropService {
    static func share(_ urls: [URL]) {
        guard !urls.isEmpty,
              let service = NSSharingService(named: .sendViaAirDrop),
              service.canPerform(withItems: urls)
        else {
            NSSound.beep()
            return
        }
        // An accessory app must be active for the sheet to come to the front.
        NSApp.activate()
        service.perform(withItems: urls)
    }
}
