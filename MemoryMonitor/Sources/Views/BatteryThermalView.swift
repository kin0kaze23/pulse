import SwiftUI

/// Battery and thermal state view
struct BatteryThermalView: View {
    @ObservedObject var healthMonitor = SystemHealthMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: batteryIcon)
                    .font(.title2)
                    .foregroundStyle(batteryColor)
                Text("Battery & Thermal")
                    .font(.title2.bold())
            }

            HStack(spacing: 24) {
                // Battery gauge
                VStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                            .frame(width: 80, height: 40)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(batteryColor.gradient)
                            .frame(width: 72 * (healthMonitor.batteryPercentage / 100.0), height: 32)
                            .animation(.easeInOut(duration: 0.5), value: healthMonitor.batteryPercentage)

                        Text(String(format: "%.0f%%", healthMonitor.batteryPercentage))
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundColor(.white)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: healthMonitor.isCharging ? "bolt.fill" : "bolt.slash")
                            .font(.caption2)
                            .foregroundColor(healthMonitor.isCharging ? .green : .secondary)
                        Text(healthMonitor.isCharging ? "Charging" : "On Battery")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Divider().frame(height: 60)

                // Battery details
                VStack(alignment: .leading, spacing: 6) {
                    BatteryDetailRow(label: "Time Remaining", value: healthMonitor.timeRemaining)
                    BatteryDetailRow(label: "Cycle Count", value: "\(healthMonitor.cycleCount)")
                    BatteryDetailRow(label: "Health", value: healthMonitor.batteryHealth)
                }

                Spacer()

                // Thermal
                VStack(spacing: 8) {
                    Image(systemName: thermalIcon)
                        .font(.system(size: 36))
                        .foregroundColor(thermalColor)

                    Text(healthMonitor.thermalState)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .foregroundColor(thermalColor)

                    Text("Thermal State")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(thermalColor.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var batteryColor: Color {
        if healthMonitor.isCharging { return .green }
        if healthMonitor.batteryPercentage > 50 { return .green }
        if healthMonitor.batteryPercentage > 20 { return .orange }
        return .red
    }

    private var batteryIcon: String {
        if healthMonitor.batteryPercentage > 75 { return "battery.100" }
        if healthMonitor.batteryPercentage > 50 { return "battery.75" }
        if healthMonitor.batteryPercentage > 25 { return "battery.50" }
        return "battery.25"
    }

    private var thermalColor: Color {
        switch healthMonitor.thermalState {
        case "Nominal": return .green
        case "Fair": return .yellow
        case "Serious": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }

    private var thermalIcon: String {
        switch healthMonitor.thermalState {
        case "Nominal": return "thermometer.low"
        case "Fair": return "thermometer.medium"
        case "Serious": return "thermometer.high"
        case "Critical": return "flame.fill"
        default: return "thermometer"
        }
    }
}

struct BatteryDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
    }
}

#Preview {
    BatteryThermalView()
        .padding()
}
