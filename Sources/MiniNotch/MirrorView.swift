import AppKit
import AVFoundation
import SwiftUI

/// Expanded-panel content while the camera mirror is open.
struct MirrorView: View {
    let mirror: CameraMirror
    let onClose: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.white.opacity(0.06)

            switch mirror.state {
            case .starting, .running:
                CameraPreview(layer: mirror.previewLayer)
            case .denied:
                message("Camera access is off.\nAllow MiniNotch in System Settings → Privacy & Security → Camera.")
            case .unavailable:
                message("No camera available.")
            case .off:
                EmptyView()
            }

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.5))
            }
            .buttonStyle(.plain)
            .padding(8)
            .accessibilityLabel("Close mirror")
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .padding(.bottom, 12)
    }

    private func message(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white.opacity(0.7))
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Hosts the shared preview layer in a layer-hosting NSView.
private struct CameraPreview: NSViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        // Assigning the layer before wantsLayer makes this a layer-hosting view.
        view.layer = layer
        view.wantsLayer = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
