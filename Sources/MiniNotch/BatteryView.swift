import SwiftUI

/// Battery percentage, power status and a matching SF Symbol.
struct BatteryView: View {
    let snapshot: BatteryMonitor.Snapshot

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 22))
                .foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(snapshot.percent)%")
                    .font(.system(size: 17, weight: .semibold).monospacedDigit())
                Text(statusText)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .fixedSize()
        .accessibilityElement(children: .combine)
    }

    private var statusText: String {
        switch snapshot.state {
        case .charging: "Charging"
        case .onAC: "On AC Power"
        case .onBattery: "On Battery"
        }
    }

    private var symbolName: String {
        switch snapshot.state {
        case .charging: return "battery.100percent.bolt"
        case .onAC: return "powerplug.fill"
        case .onBattery:
            switch snapshot.percent {
            case ..<13: return "battery.0percent"
            case ..<38: return "battery.25percent"
            case ..<63: return "battery.50percent"
            case ..<88: return "battery.75percent"
            default: return "battery.100percent"
            }
        }
    }

    private var tint: Color {
        switch snapshot.state {
        case .charging: .green
        case .onAC: .white
        case .onBattery: snapshot.percent <= 20 ? .red : .white
        }
    }
}
