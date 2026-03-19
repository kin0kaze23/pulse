import SwiftUI
import Charts

/// Network throughput view
struct NetworkView: View {
    @ObservedObject var healthMonitor = SystemHealthMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "wifi")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                Text("Network")
                    .font(.title2.bold())
                Spacer()
                Circle()
                    .fill(.green)
                    .frame(width: 8, height: 8)
                Text("Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Speed display
            HStack(spacing: 24) {
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

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Total")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "↓ %.2f GB", healthMonitor.totalDownloadGB))
                        .font(.system(.caption, design: .monospaced))
                    Text(String(format: "↑ %.2f GB", healthMonitor.totalUploadGB))
                        .font(.system(.caption, design: .monospaced))
                }
            }

            // Network history
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

struct SpeedCard: View {
    let icon: String
    let label: String
    let speed: Double
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(String(format: "%.2f", speed))
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(color)
            HStack(spacing: 2) {
                Text("MB/s")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    NetworkView()
        .padding()
}
