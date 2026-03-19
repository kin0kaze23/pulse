import SwiftUI

/// Overall health score card with recommendations
struct HealthScoreView: View {
    @ObservedObject var manager = MemoryMonitorManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                Text("Mac Health")
                    .font(.title2.bold())
                Spacer()
            }

            HStack(spacing: 24) {
                // Health score circle
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.15), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: CGFloat(manager.healthScore) / 100.0)
                        .stroke(
                            scoreGradient,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.8), value: manager.healthScore)

                    VStack(spacing: 0) {
                        Text(manager.healthGrade)
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundColor(scoreColor)
                        Text("\(manager.healthScore)")
                            .font(.system(.caption, design: .rounded, weight: .semibold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 100, height: 100)

                // Quick stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    if let memory = manager.systemMonitor.currentMemory {
                        HealthStatTile(
                            icon: "memorychip",
                            label: "Memory",
                            value: String(format: "%.0f%%", memory.usedPercentage),
                            color: memory.usedPercentage > 85 ? .red : memory.usedPercentage > 75 ? .orange : .green
                        )
                    }

                    HealthStatTile(
                        icon: "cpu",
                        label: "CPU",
                        value: String(format: "%.0f%%", manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage),
                        color: (manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage) > 80 ? .red :
                            (manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage) > 50 ? .orange : .green
                    )

                    if let disk = manager.diskMonitor.primaryDisk {
                        HealthStatTile(
                            icon: "internaldrive",
                            label: "Disk",
                            value: String(format: "%.0f%%", disk.usedPercentage),
                            color: disk.usedPercentage > 90 ? .red : disk.usedPercentage > 75 ? .orange : .green
                        )
                    }

                    HealthStatTile(
                        icon: "thermometer",
                        label: "Thermal",
                        value: manager.healthMonitor.thermalState,
                        color: thermalColor
                    )
                }
            }

            // Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)

                ForEach(Array(manager.recommendations.enumerated()), id: \.offset) { _, tip in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: tip.contains("well") ? "checkmark.circle.fill" : "lightbulb.fill")
                            .foregroundColor(tip.contains("well") ? .green : .yellow)
                            .font(.caption)
                        Text(tip)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var scoreColor: Color {
        switch manager.healthScore {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }

    private var scoreGradient: LinearGradient {
        LinearGradient(
            colors: [scoreColor, scoreColor.opacity(0.6)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var thermalColor: Color {
        switch manager.healthMonitor.thermalState {
        case "Nominal": return .green
        case "Fair": return .yellow
        case "Serious": return .orange
        case "Critical": return .red
        default: return .gray
        }
    }
}

struct HealthStatTile: View {
    let icon: String
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
            }
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundColor(color)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    HealthScoreView()
        .padding()
}
