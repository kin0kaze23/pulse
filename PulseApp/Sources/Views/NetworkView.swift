import SwiftUI
import Charts

/// Network throughput view - Premium implementation
struct NetworkView: View {
    @ObservedObject var healthMonitor = SystemHealthMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header
            
            speedSection
            
            chartSection
        }
        .premiumCard()
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "wifi")
                .font(.title2)
                .foregroundStyle(.cyan)
            Text("Network")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            connectionStatus
        }
    }
    
    private var connectionStatus: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "circle.fill")
                .font(.system(size: 8))
                .foregroundColor(.green)
            Text("Connected")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Speed Section
    
    private var speedSection: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            SpeedCard(
                icon: "arrow.down.circle.fill",
                label: "Download",
                speed: healthMonitor.downloadSpeed,
                color: .blue
            )
            SpeedCard(
                icon: "arrow.up.circle.fill",
                label: "Upload",
                speed: healthMonitor.uploadSpeed,
                color: .orange
            )
            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text("Total Session")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down")
                        .font(.caption2)
                        .foregroundColor(.blue)
                    Text(String(format: "%.2f GB", healthMonitor.totalDownloadGB))
                        .font(.system(.caption, design: .monospaced))
                }
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.caption2)
                        .foregroundColor(.orange)
                    Text(String(format: "%.2f GB", healthMonitor.totalUploadGB))
                        .font(.system(.caption, design: .monospaced))
                }
            }
        }
    }
    
    // MARK: - Chart Section
    
    private var chartSection: some View {
        Group {
            if !healthMonitor.networkHistory.isEmpty {
                Chart {
                    ForEach(healthMonitor.networkHistory) { entry in
                        LineMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("MB/s", entry.downloadMB),
                            series: .value("Direction", "Download")
                        )
                        .foregroundStyle(.blue.gradient)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", entry.timestamp),
                            y: .value("MB/s", entry.uploadMB),
                            series: .value("Direction", "Upload")
                        )
                        .foregroundStyle(.orange.gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisValueLabel {
                            if let val = value.as(Double.self) {
                                Text(String(format: "%.1f", val))
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 100)
            }
        }
    }
}

// MARK: - Speed Card

struct SpeedCard: View {
    let icon: String
    let label: String
    let speed: Double
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(String(format: "%.2f", speed))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(color)
            Text("MB/s \(label)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.medium))
    }
}

#Preview {
    NetworkView()
        .padding()
        .frame(width: 500)
}
