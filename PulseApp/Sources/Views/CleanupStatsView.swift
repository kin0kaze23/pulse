import SwiftUI

/// Cleanup stats and history view - shows total impact of using the app
struct CleanupStatsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var optimizer = MemoryOptimizer.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            header

            statsGrid

            historySection
        }
        .premiumCard()
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "chart.bar.fill")
                .font(.title2)
                .foregroundStyle(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Your Impact")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Total space reclaimed since you started using \(Brand.name)")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            StatCard(
                icon: "arrow.down.circle.fill",
                iconColor: .green,
                value: formatBytes(settings.totalFreedMB),
                label: "Total Freed"
            )

            StatCard(
                icon: "number.circle.fill",
                iconColor: .blue,
                value: "\(settings.totalCleanupCount)",
                label: "Cleanups Done"
            )

            StatCard(
                icon: "clock.fill",
                iconColor: .orange,
                value: lastCleanupText,
                label: "Last Cleanup"
            )
        }
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("CLEANUP HISTORY")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)

            if settings.totalCleanupCount == 0 {
                emptyHistoryState
            } else {
                historyList
            }
        }
    }

    private var emptyHistoryState: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("No cleanups yet")
                    .font(DesignSystem.Typography.subheadline)
                    .fontWeight(.medium)
                Text("Click Optimize to start reclaiming space")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }

    private var historyList: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            // Simulated history - in production this would be stored
            ForEach(0..<min(settings.totalCleanupCount, 5), id: \.self) { index in
                historyRow(index: index)
            }
        }
    }

    private func historyRow(index: Int) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(Color.green.opacity(0.6))
                .frame(width: 8, height: 8)

            Text("Optimization #\(settings.totalCleanupCount - index)")
                .font(DesignSystem.Typography.caption)

            Spacer()

            if index == 0, let lastDate = settings.lastCleanupDate {
                Text(lastDate, style: .relative)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Helpers

    private var lastCleanupText: String {
        if let lastDate = settings.lastCleanupDate {
            let days = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
            if days == 0 {
                return "Today"
            } else if days == 1 {
                return "Yesterday"
            } else {
                return "\(days)d ago"
            }
        }
        return "Never"
    }

    private func formatBytes(_ mb: Double) -> String {
        let gb = mb / 1024
        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        }
        return String(format: "%.0f MB", mb)
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)

            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.md)
        .background(Color.secondary.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }
}

// MARK: - Preview

#Preview {
    CleanupStatsView()
        .padding()
        .frame(width: 500)
}
