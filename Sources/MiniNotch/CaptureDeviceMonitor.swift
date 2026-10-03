import CoreAudio
import CoreMediaIO
import Foundation
import Observation

/// Reports whether any process is using a camera or a microphone.
///
/// Uses CoreMediaIO / CoreAudio "is running somewhere" property listeners on
/// every device, plus listeners on the device lists for hot-plugged hardware.
/// Everything is delivered on the main queue; nothing polls.
@MainActor
@Observable
final class CaptureDeviceMonitor {
    private(set) var isCameraInUse = false
    private(set) var isMicrophoneInUse = false

    /// Called after either flag changes.
    @ObservationIgnored var onChange: (() -> Void)?

    @ObservationIgnored private var cameraListeners: [(CMIOObjectID, CMIOObjectPropertyListenerBlock)] = []
    @ObservationIgnored private var microphoneListeners: [(AudioObjectID, AudioObjectPropertyListenerBlock)] = []

    init() {
        observeDeviceLists()
        rebuildCameraListeners()
        rebuildMicrophoneListeners()
        refresh()
    }

    // MARK: - State

    private func refresh() {
        let camera = cameraListeners.contains { CameraDevices.isRunning($0.0) }
        let microphone = microphoneListeners.contains { AudioDevices.isRunning($0.0) }
        guard camera != isCameraInUse || microphone != isMicrophoneInUse else { return }
        isCameraInUse = camera
        isMicrophoneInUse = microphone
        onChange?()
    }

    // MARK: - Listeners

    private func observeDeviceLists() {
        var cameraList = CameraDevices.address(kCMIOHardwarePropertyDevices)
        CMIOObjectAddPropertyListenerBlock(CMIOObjectID(kCMIOObjectSystemObject), &cameraList, .main) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.rebuildCameraListeners()
                self?.refresh()
            }
        }

        var audioList = AudioDevices.address(kAudioHardwarePropertyDevices)
        AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &audioList, .main) { [weak self] _, _ in
            MainActor.assumeIsolated {
                self?.rebuildMicrophoneListeners()
                self?.refresh()
            }
        }
    }

    private func rebuildCameraListeners() {
        var address = CameraDevices.address(kCMIODevicePropertyDeviceIsRunningSomewhere)
        for (device, block) in cameraListeners {
            CMIOObjectRemovePropertyListenerBlock(device, &address, .main, block)
        }
        cameraListeners = CameraDevices.all().map { device in
            let block: CMIOObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            CMIOObjectAddPropertyListenerBlock(device, &address, .main, block)
            return (device, block)
        }
    }

    private func rebuildMicrophoneListeners() {
        var address = AudioDevices.address(kAudioDevicePropertyDeviceIsRunningSomewhere)
        for (device, block) in microphoneListeners {
            AudioObjectRemovePropertyListenerBlock(device, &address, .main, block)
        }
        microphoneListeners = AudioDevices.inputDevices().map { device in
            let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            AudioObjectAddPropertyListenerBlock(device, &address, .main, block)
            return (device, block)
        }
    }
}

// MARK: - CoreMediaIO helpers

private enum CameraDevices {
    static func address(_ selector: Int) -> CMIOObjectPropertyAddress {
        CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(selector),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
    }

    static func all() -> [CMIOObjectID] {
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var address = address(kCMIOHardwarePropertyDevices)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == noErr else { return [] }
        return devices
    }

    static func isRunning(_ device: CMIOObjectID) -> Bool {
        var address = address(kCMIODevicePropertyDeviceIsRunningSomewhere)
        var running: UInt32 = 0
        var used: UInt32 = 0
        let size = UInt32(MemoryLayout<UInt32>.size)
        guard CMIOObjectGetPropertyData(device, &address, 0, nil, size, &used, &running) == noErr else { return false }
        return running != 0
    }
}

// MARK: - CoreAudio helpers

private enum AudioDevices {
    static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    /// Devices with at least one input stream.
    static func inputDevices() -> [AudioObjectID] {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return [] }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return [] }
        return devices.filter(hasInput)
    }

    private static func hasInput(_ device: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr && size > 0
    }

    static func isRunning(_ device: AudioObjectID) -> Bool {
        var address = address(kAudioDevicePropertyDeviceIsRunningSomewhere)
        var running: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(device, &address, 0, nil, &size, &running) == noErr else { return false }
        return running != 0
    }
}
