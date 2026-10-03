import SwiftUI

/// Content beside the collapsed notch: a charging toast, or camera / microphone
/// dots. The middle stays empty because a hardware notch has no pixels there.
struct CollapsedWingsView: View {
    let wingWidth: CGFloat
    let isShowingChargeToast: Bool
    let battery: BatteryMonitor
    let capture: CaptureDeviceMonitor

    var body: some View {
        HStack(spacing: 0) {
            leading
                .frame(width: wingWidth)
            Spacer(minLength: 0)
            trailing
                .frame(width: wingWidth)
        }
    }

    @ViewBuilder private var leading: some View {
        if isShowingChargeToast {
            Image(systemName: "bolt.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.green)
        } else if capture.isCameraInUse {
            IndicatorDot(color: .green)
                .accessibilityLabel("Camera in use")
        }
    }

    @ViewBuilder private var trailing: some View {
        if isShowingChargeToast, let snapshot = battery.snapshot {
            Text("\(snapshot.percent)%")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(.white)
        } else if capture.isMicrophoneInUse {
            IndicatorDot(color: .orange)
                .accessibilityLabel("Microphone in use")
        }
    }
}

private struct IndicatorDot: View {
    let color: Color

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
    }
}
