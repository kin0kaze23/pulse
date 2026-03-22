import SwiftUI
import Charts

/// CPU usage visualization with per-core history chart
struct CPUView: View {
    @ObservedObject var cpuMonitor = CPUMonitor.shared
    @ObservedObject var manager = MemoryMonitorManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            header
            
            gaugesSection
            
            chartSection
            
            processesSection
        }
        .premiumCard()
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Image(systemName: "cpu")
                .font(.title2)
                .foregroundStyle(.blue)
            Text("CPU")
                .font(.system(.title3, design: .rounded, weight: .bold))
            Spacer()
            Text(cpuMonitor.cpuName)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
    }
    
    // MARK: - Gauges
    
    private var gaugesSection: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            CPUCircleGauge(label: "User", value: cpuMonitor.userCPUPercentage, color: .blue)
            CPUCircleGauge(label: "System", value: cpuMonitor.systemCPUPercentage, color: .purple)
            CPUCircleGauge(label: "Idle", value: cpuMonitor.idleCPUPercentage, color: .green)
            Spacer()
            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text("\(cpuMonitor.coreCount)")
                    .font(.system(.title, design: .rounded, weight: .bold))
                Text("cores")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Chart
    
    private var chartSection: some View {
        Group {
            if !cpuMonitor.cpuHistory.isEmpty {
                Chart(cpuMonitor.cpuHistory) { entry in
                    AreaMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Usage %", entry.userPercent + entry.systemPercent)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue.opacity(0.4), .purple.opacity(0.15)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", entry.timestamp),
                        y: .value("Usage %", entry.userPercent + entry.systemPercent)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
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
        }
    }
    
    // MARK: - Processes
    
    private var processesSection: some View {
        Group {
            if !cpuMonitor.topCPUProcesses.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Top CPU Processes")
                        .font(DesignSystem.Typography.headline)
                    
                    ForEach(Array(cpuMonitor.topCPUProcesses.prefix(5))) { process in
                        CPUProcessRow(process: process)
                    }
                }
            }
        }
    }
}

// MARK: - CPU Process Row

struct CPUProcessRow: View {
    let process: CPUMonitor.CPUPerProcess
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text(process.name)
                .font(.system(.body, design: .rounded))
                .lineLimit(1)
            
            Spacer()
            
            Text(String(format: "%.1f%%", process.cpuPercentage))
                .font(.system(.body, design: .monospaced, weight: .semibold))
                .foregroundColor(process.cpuPercentage > 50 ? .red : .primary)
                .frame(width: 50, alignment: .trailing)
            
            // Mini bar
            CPUProgressBar(percentage: process.cpuPercentage)
                .frame(width: 80)
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .background(isHovered ? DesignSystem.Colors.hoverBackground : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.Radius.small))
        .onHover { hovering in
            withAnimation(DesignSystem.Animation.micro) { isHovered = hovering }
        }
    }
}

// MARK: - CPU Progress Bar

struct CPUProgressBar: View {
    let percentage: Double
    
    private var barColor: Color {
        percentage > 80 ? .red : percentage > 50 ? .orange : .blue
    }
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))
                RoundedRectangle(cornerRadius: 3)
                    .fill(barColor.gradient)
                    .frame(width: geo.size.width * min(percentage / 100.0, 1.0))
            }
        }
        .frame(height: 8)
    }
}

// MARK: - CPU Circle Gauge

struct CPUCircleGauge: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.15), lineWidth: DesignSystem.GaugeLineWidth.thin)
                
                Circle()
                    .trim(from: 0, to: min(value / 100.0, 1.0))
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: DesignSystem.GaugeLineWidth.thin, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.standard, value: value)

                Text(String(format: "%.0f%%", value))
                    .font(.system(.subheadline, design: .monospaced, weight: .bold))
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    CPUView()
        .padding()
        .frame(width: 500)
}
