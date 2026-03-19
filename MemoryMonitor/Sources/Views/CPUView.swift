import SwiftUI
import Charts

/// CPU usage visualization with per-core history chart
struct CPUView: View {
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @ObservedObject var manager = MemoryMonitorManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "cpu")
                    .font(.title2)
                    .foregroundStyle(.blue)
                Text("CPU")
                    .font(.title2.bold())
                Spacer()
                Text(cpuMonitor.cpuName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            // CPU Gauges
            HStack(spacing: 20) {
                CPUCircleGauge(label: "User", value: cpuMonitor.userCPUPercentage, color: .blue)
                CPUCircleGauge(label: "System", value: cpuMonitor.systemCPUPercentage, color: .purple)
                CPUCircleGauge(label: "Idle", value: cpuMonitor.idleCPUPercentage, color: .green)
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(cpuMonitor.coreCount)")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("cores")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // CPU History Chart
            if !cpuMonitor.cpuHistory.isEmpty {
                Chart(cpuMonitor.cpuHistory) { entry in
                    AreaMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Usage %", entry.userPercent + entry.systemPercent)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue.opacity(0.4), .purple.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Usage %", entry.userPercent + entry.systemPercent)
                    )
                    .foregroundStyle(.blue.gradient)
                    .interpolationMethod(.catmullRom)
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisValueLabel {
                            if let val = value.as(Int.self) {
                                Text("\(val)%")
                                    .font(.caption2)
                            }
                        }
                    }
                }
                .frame(height: 120)
            }

            // Top CPU Processes
            if !cpuMonitor.topCPUProcesses.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top CPU Processes")
                        .font(.headline)

                    ForEach(cpuMonitor.topCPUProcesses.prefix(5)) { process in
                        HStack {
                            Text(process.name)
                                .font(.system(.body, design: .rounded))
                                .lineLimit(1)
                            Spacer()
                            Text(String(format: "%.1f%%", process.cpuPercentage))
                                .font(.system(.body, design: .monospaced, weight: .semibold))
                                .foregroundColor(process.cpuPercentage > 50 ? .red : .primary)

                            // Mini bar
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 2).fill(Color.gray.opacity(0.15))
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(process.cpuPercentage > 50 ? Color.red.gradient : Color.blue.gradient)
                                        .frame(width: geo.size.width * min(process.cpuPercentage / 100.0, 1.0))
                                }
                            }
                            .frame(width: 80, height: 6)
                        }
                    }
                }
            }
        }
    }
}

struct CPUCircleGauge: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: min(value / 100.0, 1.0))
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: value)

                Text(String(format: "%.0f%%", value))
                    .font(.system(.caption, design: .monospaced, weight: .bold))
            }
            .frame(width: 56, height: 56)

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CPUView()
        .padding()
}
