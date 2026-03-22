import SwiftUI

/// Overall health score card with recommendations and breakdown
struct HealthScoreView: View {
    @ObservedObject var manager = MemoryMonitorManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .font(.title2)
                    .foregroundStyle(.pink)
                VStack(alignment: .leading, spacing: 2) {
                    Text(Brand.name)
                        .font(.title2.bold())
                    Text("Live health score with clear next steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
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

            // Score Breakdown (why is the score what it is)
            if !manager.healthBreakdown.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Score Breakdown")
                        .font(.subheadline.bold())
                        .foregroundColor(.secondary)

                    ForEach(manager.healthBreakdown, id: \.category) { penalty in
                        HStack(spacing: 8) {
                            Text(penalty.category)
                                .font(.caption.bold())
                                .frame(width: 60, alignment: .leading)
                            Text("-\(penalty.pointsLost) pts")
                                .font(.system(.caption, design: .monospaced, weight: .bold))
                                .foregroundColor(.red)
                            Text(penalty.reason)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                    }
                }
                .padding(10)
                .background(Color.red.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Actionable Recommendations
            VStack(alignment: .leading, spacing: 8) {
                Text("Recommendations")
                    .font(.headline)

                ForEach(manager.actionableRecommendations) { tip in
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: tip.icon)
                            .foregroundColor(severityColor(tip.severity))
                            .font(.body)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(tip.title)
                                .font(.caption.bold())
                            Text(tip.detail)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Action button
                        actionButton(for: tip)
                    }
                    .padding(8)
                    .background(severityColor(tip.severity).opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButton(for tip: MemoryMonitorManager.Recommendation) -> some View {
        switch tip.action {
        case .freeRAM, .cleanCaches, .freeDiskSpace:
            Button {
                manager.freeRAM()
            } label: {
                if manager.optimizer.isWorking {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Fix", systemImage: "bolt.fill")
                        .font(.caption.bold())
                }
            }
            .buttonStyle(.bordered)
            .tint(.blue)
            .disabled(manager.optimizer.isWorking)

        case .closeApp(_, let pid, _):
            Button {
                manager.processMonitor.killProcess(pid: pid)
                manager.processMonitor.refresh(topN: manager.settings.topProcessesCount)
            } label: {
                Label("Close", systemImage: "xmark.circle")
                    .font(.caption.bold())
            }
            .buttonStyle(.bordered)
            .tint(.red)

        case .coolDown, .none:
            EmptyView()
        }
    }

    // MARK: - Helpers

    private func severityColor(_ severity: MemoryMonitorManager.Recommendation.Severity) -> Color {
        switch severity {
        case .info: return .green
        case .warning: return .orange
        case .critical: return .red
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
