import SwiftUI

/// Optimizer view — Process management and system cleanup
/// Note: "Optimizer" is a misnomer - we advise on memory, we don't optimize it
struct OptimizerView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader(icon: "sparkles", title: "Memory Advisor", subtitle: "Process management and cache cleanup")

            ProcessListView()
                .staggeredEntrance(delay: 0.05)
            Divider()
            AutoKillView()
                .staggeredEntrance(delay: 0.1)
            Divider()
            CleanupStatsView()
                .staggeredEntrance(delay: 0.15)
        }
    }

    private func sectionHeader(icon: String, title: String, subtitle: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.orange)
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