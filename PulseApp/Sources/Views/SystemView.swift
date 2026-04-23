import SwiftUI

/// System view — CPU, Disk, Network, Battery in one place
struct SystemView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader(icon: "cpu", title: "System", subtitle: "CPU, Disk, Network, Battery")
            
            CPUView()
                .staggeredEntrance(delay: 0.05)
            Divider()
            DiskView()
                .staggeredEntrance(delay: 0.1)
            Divider()
            HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
                NetworkView()
                    .staggeredEntrance(delay: 0.15)
                BatteryThermalView()
                    .staggeredEntrance(delay: 0.2)
            }
        }
    }
    
    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.purple)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text(subtitle)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}