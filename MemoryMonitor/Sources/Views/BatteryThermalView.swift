import SwiftUI

/// Battery and thermal state view - Premium implementation
struct BatteryThermalView: View {
    @ObservedObject var healthMonitor = SystemHealthMonitor.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header
            
            HStack(spacing: DesignSystem.Spacing.lg) {
                batteryGauge
                    .frame(maxWidth: 140)
                
                Divider()
                    .frame(height: 60)
                
                batteryDetails
                
                Spacer()
                
                thermalIndicator
            }
        }
        .premiumCard()
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "battery.100.bolt")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Battery & Thermal")
                .font(.system(.title3, design: .rounded, weight: .bold))
        }
    }
    
    // MARK: - Battery Gauge (Proper implementation with clipping)
    
    private var batteryGauge: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ZStack {
                // Background track
                RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 80, height: 40)
                
                // Battery fill - properly clipped
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium - 2)
                        .fill(batteryColor.gradient)
                        .frame(width: geo.size.width * (healthMonitor.batteryPercentage / 100.0))
                }
                .frame(width: 76, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium - 2))
                
                // Battery percentage text
                Text(String(format: "%.0f%%", healthMonitor.batteryPercentage))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(batteryColor)
                    .animation(.easeInOut(duration: 0.3), value: healthMonitor.batteryPercentage)
            }
            
            // Charging status
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: healthMonitor.isCharging ? "bolt.circle.fill" : "bolt.slash")
                    .font(.system(size: 12))
                    .foregroundColor(healthMonitor.isCharging ? .green : .secondary)
                Text(healthMonitor.isCharging ? "Charging" : "On Battery")
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Battery Details
    
    private var batteryDetails: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            BatteryDetailRow(label: "Time Remaining", value: healthMonitor.timeRemaining)
            BatteryDetailRow(label: "Cycle Count", value: "\(healthMonitor.cycleCount)")
            BatteryDetailRow(label: "Health", value: healthMonitor.batteryHealth)
        }
    }
    
    // MARK: - Thermal Indicator
    
    private var thermalIndicator: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: thermalIcon)
                .font(.system(size: 28))
                .foregroundColor(thermalColor)
            
            VStack(spacing: 2) {
                Text(healthMonitor.thermalState)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(thermalColor)
                
                Text("Thermal")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(minWidth: 80)
        .background(thermalColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }
    
    // MARK: - Helpers
    
    private var batteryColor: Color {
        if healthMonitor.isCharging { return .green }
        if healthMonitor.batteryPercentage > 50 { return .green }
        if healthMonitor.batteryPercentage > 20 { return .orange }
        return .red
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
    
    private var thermalColor: Color {
        switch healthMonitor.thermalState {
        case "Nominal": return .green
        case "Fair": return .yellow
        case "Serious": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }
}

// MARK: - Battery Detail Row

struct BatteryDetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Text(label)
                .font(.system(.caption, design: .rounded))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
    }
}

#Preview {
    BatteryThermalView()
        .padding()
        .frame(width: 500)
}
