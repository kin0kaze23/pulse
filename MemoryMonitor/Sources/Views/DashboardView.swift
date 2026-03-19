import SwiftUI

/// Main dashboard with comprehensive health monitoring
struct DashboardView: View {
    @ObservedObject var manager = MemoryMonitorManager.shared
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared
    @State private var selectedTab: Tab = .overview

    enum Tab: String, CaseIterable {
        case overview = "Overview"
        case memory = "Memory"
        case cpu = "CPU"
        case disk = "Disk"
        case network = "Network"
        case processes = "Processes"
        case guard_ = "Guard"

        var icon: String {
            switch self {
            case .overview: return "square.grid.2x2"
            case .memory: return "memorychip"
            case .cpu: return "cpu"
            case .disk: return "internaldrive"
            case .network: return "wifi"
            case .processes: return "list.bullet.rectangle"
            case .guard_: return "shield.checkered"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar with health score
            topBar

            Divider()

            // Sidebar + Content
            HStack(spacing: 0) {
                // Sidebar navigation
                sidebar

                Divider()

                // Main content
                ScrollView {
                    contentSection
                        .padding(20)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .frame(minWidth: 800, idealWidth: 900, minHeight: 600, idealHeight: 650)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Health score
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: CGFloat(manager.healthScore) / 100.0)
                        .stroke(scoreColor.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(manager.healthGrade)
                        .font(.system(.title3, design: .rounded, weight: .bold))
                        .foregroundColor(scoreColor)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Mac Health")
                        .font(.caption.bold())
                    Text("Score: \(manager.healthScore)/100")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Divider().frame(height: 30)

            // Quick stats
            if let memory = systemMonitor.currentMemory {
                QuickStatPill(icon: "memorychip", value: String(format: "%.0f%%", memory.usedPercentage), color: memoryColor)
            }
            QuickStatPill(icon: "cpu", value: String(format: "%.0f%%", manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage), color: cpuColor)
            if let disk = manager.diskMonitor.primaryDisk {
                QuickStatPill(icon: "internaldrive", value: String(format: "%.0f%%", disk.usedPercentage), color: diskColor)
            }
            QuickStatPill(icon: "thermometer", value: manager.healthMonitor.thermalState, color: thermalColor)

            Spacer()

            // Actions
            Button {
                manager.killTopMemoryProcess()
            } label: {
                Label("Kill Top", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)
            .tint(.red)
            .disabled(manager.processMonitor.topProcesses.isEmpty)

            Button {
                manager.processMonitor.refresh(topN: manager.settings.topProcessesCount)
                manager.systemMonitor.updateMemoryInfo()
                manager.cpuMonitor.update()
                manager.diskMonitor.refresh()
                manager.healthMonitor.update()
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 2) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) { selectedTab = tab }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: tab.icon)
                            .frame(width: 18)
                        Text(tab.rawValue)
                            .font(.system(.body, weight: selectedTab == tab ? .semibold : .regular))
                        Spacer()
                    }
                    .foregroundColor(selectedTab == tab ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == tab
                            ? Color.accentColor
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Battery at bottom
            HStack(spacing: 6) {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                Text(String(format: "%.0f%%", manager.healthMonitor.batteryPercentage))
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding(8)
        .frame(width: 160)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .overview:
            OverviewContent()
        case .memory:
            MemorySection()
        case .cpu:
            CPUView()
        case .disk:
            DiskView()
        case .network:
            VStack(spacing: 20) {
                NetworkView()
                BatteryThermalView()
            }
        case .processes:
            ProcessListView()
        case .guard_:
            AutoKillView()
        }
    }

    // MARK: - Computed Colors

    private var scoreColor: Color {
        switch manager.healthScore {
        case 90...100: return .green
        case 80..<90: return .blue
        case 70..<80: return .yellow
        case 50..<70: return .orange
        default: return .red
        }
    }

    private var memoryColor: Color {
        guard let mem = systemMonitor.currentMemory else { return .gray }
        return mem.usedPercentage > 85 ? .red : mem.usedPercentage > 75 ? .orange : .green
    }

    private var cpuColor: Color {
        let cpu = manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage
        return cpu > 80 ? .red : cpu > 50 ? .orange : .green
    }

    private var diskColor: Color {
        guard let disk = manager.diskMonitor.primaryDisk else { return .gray }
        return disk.usedPercentage > 90 ? .red : disk.usedPercentage > 75 ? .orange : .green
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

    private var batteryIcon: String {
        let pct = manager.healthMonitor.batteryPercentage
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        let pct = manager.healthMonitor.batteryPercentage
        if manager.healthMonitor.isCharging { return .green }
        return pct > 20 ? .green : .red
    }
}

// MARK: - Quick Stat Pill

struct QuickStatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Overview Content

struct OverviewContent: View {
    @ObservedObject var manager = MemoryMonitorManager.shared

    var body: some View {
        VStack(spacing: 20) {
            // Health score + recommendations
            HealthScoreView()

            Divider()

            // Memory overview
            if let memory = manager.systemMonitor.currentMemory {
                MemoryBreakdownView(memory: memory)
            }

            Divider()

            // Two-column: CPU + Disk
            HStack(alignment: .top, spacing: 20) {
                CPUView()
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 300)

                DiskView()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            // Network
            NetworkView()

            Divider()

            // Top processes
            ProcessListView()
        }
    }
}

// MARK: - Memory Section

struct MemorySection: View {
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared

    var body: some View {
        VStack(spacing: 20) {
            if let memory = systemMonitor.currentMemory {
                HStack(spacing: 24) {
                    MemoryGaugeView(
                        percentage: memory.usedPercentage,
                        pressureLevel: systemMonitor.pressureLevel,
                        size: 140
                    )

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Memory Usage")
                            .font(.title2.bold())
                        QuickStatRow(label: "Used", value: String(format: "%.2f GB", memory.usedGB), color: .blue)
                        QuickStatRow(label: "Free", value: String(format: "%.2f GB", memory.freeGB), color: .green)
                        QuickStatRow(label: "Cached", value: String(format: "%.2f GB", memory.cachedGB), color: .gray)
                        QuickStatRow(label: "Compressed", value: String(format: "%.2f GB", memory.compressedGB), color: .cyan)
                        QuickStatRow(label: "Wired", value: String(format: "%.2f GB", memory.wiredGB), color: .purple)
                        QuickStatRow(label: "Swap Used", value: String(format: "%.2f GB", memory.swapUsedGB), color: .orange)
                    }
                    Spacer()
                }

                MemoryBreakdownView(memory: memory)
            }

            MemoryHistoryView()
        }
    }
}

struct QuickStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.system(.caption, design: .rounded, weight: .semibold))
        }
        .frame(width: 200)
    }
}

#Preview {
    DashboardView()
}
