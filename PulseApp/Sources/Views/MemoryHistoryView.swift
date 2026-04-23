import SwiftUI
import Charts

/// Memory usage history chart
struct MemoryHistoryView: View {
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Memory History")
                .font(.headline)

            if systemMonitor.memoryHistory.isEmpty {
                ContentUnavailableView("Collecting data...", systemImage: "chart.line.uptrend.xyaxis")
                    .frame(height: 150)
            } else {
                Chart(systemMonitor.memoryHistory) { entry in
                    LineMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Usage %", entry.usedPercentage)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Usage %", entry.usedPercentage)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    // Warning threshold line
                    RuleMark(y: .value("Warning", 85))
                        .foregroundStyle(.orange.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))

                    // Critical threshold line
                    RuleMark(y: .value("Critical", 95))
                        .foregroundStyle(.red.opacity(0.5))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)%")
                                    .font(.caption2)
                            }
                        }
                        AxisGridLine()
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .minute, count: 10)) { value in
                        AxisValueLabel(format: .dateTime.hour().minute())
                    }
                }
                .frame(height: 180)

                // Stats row
                HStack(spacing: 20) {
                    StatBadge(label: "Current", value: String(format: "%.1f%%", systemMonitor.currentMemory?.usedPercentage ?? 0))
                    StatBadge(label: "Peak (1h)", value: String(format: "%.1f%%", systemMonitor.peakMemoryInLast(minutes: 60)?.usedPercentage ?? 0))
                    StatBadge(label: "Average (1h)", value: String(format: "%.1f%%", systemMonitor.averageMemoryInLast(minutes: 60)))
                    StatBadge(label: "Swap Used", value: String(format: "%.2f GB", systemMonitor.currentMemory?.swapUsedGB ?? 0))
                }
            }
        }
    }
}

struct StatBadge: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.caption, design: .monospaced, weight: .bold))
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

#Preview {
    MemoryHistoryView()
        .padding()
}
