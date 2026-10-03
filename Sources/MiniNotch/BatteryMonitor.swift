import Foundation
import IOKit.ps
import Observation

/// Internal battery state, updated only when IOKit reports a power source change.
@MainActor
@Observable
final class BatteryMonitor {
    enum PowerState: Equatable {
        case charging, onAC, onBattery
    }

    struct Snapshot: Equatable {
        var percent: Int
        var state: PowerState
    }

    /// `nil` on Macs without an internal battery.
    private(set) var snapshot: Snapshot?

    /// Called when a charger is connected while running on battery.
    @ObservationIgnored var onPowerConnected: (() -> Void)?

    @ObservationIgnored private var runLoopSource: CFRunLoopSource?

    init() {
        snapshot = Self.readInternalBattery()
        startObserving()
    }

    private func startObserving() {
        // The monitor lives as long as the app, so an unretained context is safe.
        let context = Unmanaged.passUnretained(self).toOpaque()
        let callback: IOPowerSourceCallbackType = { context in
            guard let context else { return }
            let monitor = Unmanaged<BatteryMonitor>.fromOpaque(context).takeUnretainedValue()
            // The source is attached to the main run loop, so this runs on the main thread.
            MainActor.assumeIsolated {
                monitor.refresh()
            }
        }
        guard let source = IOPSNotificationCreateRunLoopSource(callback, context)?.takeRetainedValue() else {
            return
        }
        // Common modes: keep updating during menu tracking and drags.
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        runLoopSource = source
    }

    private func refresh() {
        let latest = Self.readInternalBattery()
        // Avoid invalidating SwiftUI when nothing visible changed.
        guard latest != snapshot else { return }
        let wasOnBattery = snapshot?.state == .onBattery
        snapshot = latest
        if wasOnBattery, let latest, latest.state != .onBattery {
            onPowerConnected?()
        }
    }

    private static func readInternalBattery() -> Snapshot? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?
                    .takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }

            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = description[kIOPSMaxCapacityKey] as? Int ?? 100
            let percent = maximum > 0 ? Int((Double(current) / Double(maximum) * 100).rounded()) : 0
            let isOnAC = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            let isCharging = description[kIOPSIsChargingKey] as? Bool ?? false

            let state: PowerState = isCharging ? .charging : (isOnAC ? .onAC : .onBattery)
            return Snapshot(percent: min(max(percent, 0), 100), state: state)
        }
        return nil
    }
}
