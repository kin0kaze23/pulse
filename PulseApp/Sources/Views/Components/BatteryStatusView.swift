import SwiftUI

/// Reusable battery status display component
struct BatteryStatusView: View {
    let percentage: Double
    let isCharging: Bool
    
    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)
            Text(String(format: "%.0f%%", percentage))
                .font(DesignSystem.Typography.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    private var batteryIcon: String {
        if isCharging { return "battery.100.bolt" }
        if percentage > 75 { return "battery.100" }
        if percentage > 50 { return "battery.75" }
        if percentage > 25 { return "battery.50" }
        return "battery.25"
    }
    
    private var batteryColor: Color {
        return DesignSystem.Colors.battery(percentage, isCharging: isCharging)
    }
}