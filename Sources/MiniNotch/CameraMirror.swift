import AVFoundation
import Observation

/// Mirrored live camera preview. The capture session runs only while the
/// mirror is shown, and the object itself is created on first use.
@MainActor
@Observable
final class CameraMirror {
    enum State: Equatable {
        case off, starting, running, denied, unavailable
    }

    private(set) var state: State = .off

    @ObservationIgnored let previewLayer: AVCaptureVideoPreviewLayer
    @ObservationIgnored private let capture = CaptureSession()

    init() {
        previewLayer = AVCaptureVideoPreviewLayer(session: capture.session)
        previewLayer.videoGravity = .resizeAspectFill
    }

    func start() {
        guard state == .off else { return }
        state = .starting
        Task { [weak self] in
            guard await Self.requestAccess() else {
                self?.finishStart(.denied)
                return
            }
            guard let capture = self?.capture else { return }
            let running = await capture.start()
            self?.finishStart(running ? .running : .unavailable)
        }
    }

    func stop() {
        state = .off
        capture.stop()
    }

    private func finishStart(_ result: State) {
        guard state == .starting else {
            // Stopped while starting: make sure the camera does not stay on.
            capture.stop()
            return
        }
        state = result
        if result == .running, let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            // Set explicitly so the preview always behaves like a mirror, whatever the camera.
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = true
        }
    }

    private static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }
}

/// Owns the AVCaptureSession and confines every call on it to one serial
/// queue, because startRunning/stopRunning block. That confinement is what
/// makes the unchecked Sendable conformance sound.
private final class CaptureSession: @unchecked Sendable {
    let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "com.stark.mininotch.camera")
    private var isConfigured = false

    /// Configures on first use and starts the session; returns whether it is running.
    func start() async -> Bool {
        await withCheckedContinuation { continuation in
            queue.async {
                guard self.configureIfNeeded() else {
                    continuation.resume(returning: false)
                    return
                }
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                continuation.resume(returning: self.session.isRunning)
            }
        }
    }

    func stop() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    private func configureIfNeeded() -> Bool {
        if isConfigured { return true }
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device)
        else { return false }

        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .high
        guard session.canAddInput(input) else { return false }
        session.addInput(input)
        isConfigured = true
        return true
    }
}
