import SwiftUI

/// Premium menu bar popover — The Orb. One glance, one action, alive.
struct MenuBarLiteView: View {
    @ObservedObject var manager: MemoryMonitorManager
    @ObservedObject var devMonitor = DeveloperMonitor.shared
    @State private var animateGauges = false

    var body: some View {
        VStack(spacing: 0) {
            // The Orb — the centerpiece
            VitalityOrb(
                healthScore: manager.healthScore,
                memoryPercent: memoryPercent,
                cpuPercent: cpuPercent
            )
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Status sentence
            Text(statusSentence)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .padding(.bottom, 2)

            Text(String(format: "%.1f GB of %.0f GB", memoryUsedGB, memoryTotalGB))
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.bottom, 16)

            // Three mini gauges
            HStack(spacing: 10) {
                litGauge(label: "RAM", value: memoryValue, color: memoryColor, pct: animateGauges ? memoryPercent : 0)
                litGauge(label: "Swap", value: String(format: "%.1f", devMonitor.swapUsedGB), color: swapColor, pct: animateGauges ? swapPercent : 0)
                litGauge(label: "CPU", value: cpuValue, color: cpuColor, pct: animateGauges ? cpuPercent : 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 14)

            // Optimize button — always visible, shimmer when working
            optimizeButton

            // Result banner
            if let result = manager.optimizer.lastResult,
               Date().timeIntervalSince(result.timestamp) < 8 {
                resultBanner(result)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Issue warning
            if let issue = issueWarning {
                issueBanner(issue)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Divider()
                .padding(.horizontal, 12)

            // Navigation
            navigationBar
        }
        .frame(width: 280)
        .animation(DesignSystem.Animation.standard, value: manager.optimizer.isWorking)
        .animation(DesignSystem.Animation.standard, value: manager.optimizer.lastResult?.timestamp)
        .onAppear {
            devMonitor.start()
            withAnimation(DesignSystem.Animation.entrance.delay(0.1)) { animateGauges = true }
        }
        .onDisappear { } // Don't stop - let it run continuously
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(nsColor: .windowBackgroundColor))
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.thinMaterial)
                    .opacity(0.4)
            }
        )
    }
    
    // MARK: - Optimize Button
    
    private var optimizeButton: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            Button {
                HapticFeedback.medium()
                manager.freeRAM()
            } label: {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    if manager.optimizer.isWorking {
                        ProgressView()
                            .controlSize(.small)
                            .tint(.white)
                        Text(manager.optimizer.statusMessage.isEmpty ? "Optimizing..." : manager.optimizer.statusMessage)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: DesignSystem.Icon.tiny, weight: .bold))
                        Text("Optimize Now")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 10, weight: .bold))
                            .opacity(0.7)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DesignSystem.Spacing.sm + 6)
                .padding(.vertical, DesignSystem.Spacing.sm + 4)
                .background(
                    Capsule()
                        .fill(Color.accentColor.gradient)
                )
                .foregroundColor(.white)
                .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 2)
            }
            .shimmer(active: manager.optimizer.isWorking)
            .buttonStyle(.plain)
            .disabled(manager.optimizer.isWorking)
            
            // Last updated timestamp
            if let lastUpdated = manager.systemMonitor.lastUpdated {
                Text("Updated \(timeAgo(from: lastUpdated))")
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 5 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
    
    // MARK: - Result Banner
    
    private func resultBanner(_ result: MemoryOptimizer.OptimizeResult) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignSystem.Icon.medium, weight: .medium))
                .foregroundColor(.green)
                .symbolEffect(.bounce, value: result.timestamp)
            VStack(alignment: .leading, spacing: 1) {
                Text("Done")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                Text(result.summary)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(Color.green.opacity(0.1))
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Issue Banner
    
    private func issueBanner(_ issue: IssueItem) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: issue.icon)
                .font(.system(size: DesignSystem.Icon.small, weight: .medium))
                .foregroundColor(issue.color)
            VStack(alignment: .leading, spacing: 1) {
                Text(issue.title)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                Text(issue.detail)
                    .font(.system(size: 9, design: .rounded))
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            if let action = issue.action, let label = issue.actionLabel {
                Button {
                    HapticFeedback.medium()
                    action()
                } label: {
                    Text(label)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .padding(.horizontal, DesignSystem.Spacing.sm + 2)
                        .padding(.vertical, DesignSystem.Spacing.xs + 1)
                        .background(issue.color.gradient)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DesignSystem.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(issue.color.opacity(0.08))
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }
    
    // MARK: - Navigation Bar
    
    private var navigationBar: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            navPill(icon: "square.grid.2x2", label: "Dashboard") {
                NavigationManager.shared.navigate(to: .dashboard)
            }
            navPill(icon: "gearshape", label: "Settings") {
                NavigationManager.shared.navigate(to: .settings)
            }
            Spacer()
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
                    .font(.system(size: DesignSystem.Icon.tiny, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(DesignSystem.Spacing.xs + 2)
                    .background(Capsule().fill(Color.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .hoverEffect()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm + 2)
    }

    // MARK: - Mini Gauge

    private func litGauge(label: String, value: String, color: Color, pct: Double) -> some View {
        VStack(spacing: DesignSystem.Spacing.xs + 2) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: CGFloat(min(pct, 100)) / 100.0)
                    .stroke(
                        color.gradient,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(DesignSystem.Animation.emphasis, value: pct)
                VStack(spacing: 0) {
                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(color)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 58, height: 58)

            Text(label.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignSystem.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(color.opacity(0.06))
        )
    }

    // MARK: - Nav Pill

    private func navPill(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: DesignSystem.Icon.tiny, weight: .medium))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
            }
            .foregroundColor(.primary.opacity(0.7))
            .padding(.horizontal, DesignSystem.Spacing.sm + 2)
            .padding(.vertical, DesignSystem.Spacing.xs + 2)
            .background(Capsule().fill(Color.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }

    // MARK: - Issue Model

    private struct IssueItem {
        let icon: String
        let title: String
        let detail: String
        let color: Color
        let actionLabel: String?
        let action: (() -> Void)?
    }

    private var issueWarning: IssueItem? {
        if devMonitor.swapUsedGB > 10 {
            return IssueItem(icon: "arrow.triangle.2.circlepath", title: "Restart Mac", detail: String(format: "%.1f GB swap — slows everything down", devMonitor.swapUsedGB), color: .red, actionLabel: nil, action: nil)
        }
        if devMonitor.opencodeDBSizeMB > 500 {
            return IssueItem(icon: "cylinder.fill", title: "DB bloated", detail: String(format: "%.0f MB in RAM", devMonitor.opencodeDBSizeMB), color: .red, actionLabel: "Clean", action: { devMonitor.cleanOpencodeDB() })
        }
        if devMonitor.hasStandaloneSessions {
            return IssueItem(icon: "bolt.slash.fill", title: "Standalone sessions", detail: "Wasting RAM", color: .orange, actionLabel: "Kill", action: { devMonitor.killStandaloneSessions() })
        }
        if devMonitor.browserTabCount > 30 {
            return IssueItem(icon: "macwindow.on.rectangle", title: "\(devMonitor.browserTabCount) tabs", detail: String(format: "%.0f MB — close some", devMonitor.browserTotalMB), color: .orange, actionLabel: nil, action: nil)
        }
        return nil
    }

    // MARK: - Computed

    private var statusSentence: String {
        if manager.healthScore >= 90 { return "Your Mac is healthy" }
        if manager.healthScore >= 70 { return "Needs attention" }
        return "Critical"
    }

    private var memoryUsedGB: Double { manager.systemMonitor.currentMemory?.usedGB ?? 0 }
    private var memoryTotalGB: Double { manager.systemMonitor.currentMemory?.totalGB ?? 18 }

    private var memoryValue: String {
        guard let mem = manager.systemMonitor.currentMemory else { return "—" }
        return String(format: "%.0f%%", mem.usedPercentage)
    }

    private var memoryColor: Color {
        guard let mem = manager.systemMonitor.currentMemory else { return .gray }
        return mem.usedPercentage > 85 ? .red : mem.usedPercentage > 75 ? .orange : .green
    }

    private var memoryPercent: Double { manager.systemMonitor.currentMemory?.usedPercentage ?? 0 }

    private var swapColor: Color {
        if devMonitor.swapUsedGB > 15 { return .red }
        if devMonitor.swapUsedGB > 8 { return .orange }
        if devMonitor.swapUsedGB > 3 { return .yellow }
        return .green
    }

    private var swapPercent: Double {
        guard devMonitor.swapTotalGB > 0 else { return 0 }
        return min(devMonitor.swapUsedGB / devMonitor.swapTotalGB * 100, 100)
    }

    private var cpuValue: String {
        String(format: "%.0f%%", manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage)
    }

    private var cpuColor: Color {
        let total = manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage
        return total > 80 ? .red : total > 50 ? .orange : .green
    }

    private var cpuPercent: Double {
        Double(manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage)
    }
}

#Preview {
    MenuBarLiteView(manager: MemoryMonitorManager.shared)
}
