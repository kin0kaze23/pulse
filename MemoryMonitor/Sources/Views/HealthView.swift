import SwiftUI

/// Premium Health view — Jony Ive level. Bento layout with hero card + status stack.
struct HealthView: View {
    @ObservedObject var manager = MemoryMonitorManager.shared
    @ObservedObject var devMonitor = DeveloperMonitor.shared
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared
    @ObservedObject var suggestions = SmartSuggestions.shared
    @State private var showKillConfirmation = false
    @State private var processToKill: ProcessMemoryInfo?
    @State private var showSuccess = false
    @State private var successMessage = ""
    @State private var animateScore = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Bento Grid: Hero + Status Stack
            bentoGrid
                .staggeredEntrance(delay: 0.1)

            // Primary Action Card (if issue)
            if let primary = primaryIssue {
                primaryActionCard(issue: primary)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .staggeredEntrance(delay: 0.15)
            }

            // Recoverable Space Banner (if significant)
            if suggestions.totalRecoverableGB > 1 {
                recoverableBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .staggeredEntrance(delay: 0.18)
            }

            // Success toast
            if showSuccess {
                successToast
                    .transition(.scale.combined(with: .opacity))
            }

            // Quick Processes
            topProcesses
                .staggeredEntrance(delay: 0.2)

            // Smart Suggestions
            smartSuggestions
                .staggeredEntrance(delay: 0.25)
        }
        .padding(DesignSystem.Spacing.lg)
        .animation(DesignSystem.Animation.standard, value: manager.healthScore)
        .animation(DesignSystem.Animation.standard, value: showSuccess)
        .onAppear {
            devMonitor.start()
            suggestions.analyze()
            withAnimation(DesignSystem.Animation.entrance.delay(0.2)) { animateScore = true }
        }
        .onDisappear { } // Don't stop - let it run continuously
        .alert("Terminate Process?", isPresented: $showKillConfirmation) {
            Button("Cancel", role: .cancel) { processToKill = nil }
            Button("Terminate", role: .destructive) {
                if let proc = processToKill {
                    manager.processMonitor.killProcess(pid: proc.id)
                    manager.processMonitor.refresh(topN: manager.settings.topProcessesCount)
                    showSuccessToast("Terminated \(proc.name)")
                }
                processToKill = nil
            }
        } message: {
            if let proc = processToKill {
                Text("\"\(proc.name)\" is using \(String(format: "%.1f GB", proc.memoryGB))")
            }
        }
    }

    // MARK: - Bento Grid

    private var bentoGrid: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.lg) {
            // Hero Card (left) - 60%
            heroCard
                .frame(maxWidth: .infinity)

            // Status Stack (right) - 40%
            statusStack
                .frame(maxWidth: 220)
        }
    }

    // MARK: - Hero Card

    private var heroCard: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Vitality Orb - the breathing centerpiece (includes grade inside)
            VitalityOrb(
                healthScore: manager.healthScore,
                memoryPercent: memoryPercent,
                cpuPercent: 0
            )
            .frame(width: 160, height: 160)

            // Status Sentence
            Text(statusSentence)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
                .contentTransition(.interpolate)

            // Memory Detail
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: "memorychip")
                    .font(.caption2)
                Text(String(format: "%.1f GB of %.0f GB used", memoryUsedGB, memoryTotalGB))
            }
            .font(.system(.subheadline, design: .rounded))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.xl)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.xlarge)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xlarge)
                        .stroke(
                            LinearGradient(
                                colors: [scoreColor.opacity(0.3), scoreColor.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: scoreColor.opacity(0.08), radius: 20, y: 8)
        )
    }

    // MARK: - Status Stack

    private var statusStack: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Memory Status
            statusTile(
                icon: "memorychip.fill",
                label: "MEMORY",
                value: memoryPercentText,
                detail: String(format: "%.0f GB", memoryUsedGB),
                color: memoryColor,
                percent: memoryPercent
            )

            // Swap Status
            statusTile(
                icon: "arrow.triangle.2.circlepath",
                label: "SWAP",
                value: String(format: "%.1f GB", devMonitor.swapUsedGB),
                detail: devMonitor.swapUsedGB > 10 ? "Restart Recommended" : "Normal",
                color: swapColor,
                percent: swapPercent,
                alert: devMonitor.swapUsedGB > 10
            )

            // Tabs Status
            statusTile(
                icon: "macwindow.on.rectangle",
                label: "BROWSER TABS",
                value: "\(devMonitor.browserTabCount)",
                detail: String(format: "%.0f MB", devMonitor.browserTotalMB),
                color: devMonitor.browserTabCount > 25 ? .orange : .green,
                percent: browserPercent,
                alert: devMonitor.browserTabCount > 30
            )
        }
    }

    private func statusTile(
        icon: String,
        label: String,
        value: String,
        detail: String,
        color: Color,
        percent: Double,
        alert: Bool = false
    ) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .foregroundColor(.secondary)
                    .tracking(1)

                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .contentTransition(.numericText())

                Text(detail)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(alert ? .red : .secondary)
            }

            Spacer()

            // Mini Gauge
            miniGauge(percent: percent, color: color)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                        .stroke(alert ? Color.red.opacity(0.2) : Color.clear, lineWidth: 1)
                )
        )
        .hoverEffect()
    }

    private func miniGauge(percent: Double, color: Color) -> some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: DesignSystem.GaugeLineWidth.thin)

            Circle()
                .trim(from: 0, to: CGFloat(min(percent, 100)) / 100.0)
                .stroke(
                    color.gradient,
                    style: StrokeStyle(lineWidth: DesignSystem.GaugeLineWidth.thin, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(DesignSystem.Animation.standard, value: percent)
        }
        .frame(width: 40, height: 40)
    }

    // MARK: - Primary Action Card

    private func primaryActionCard(issue: PrimaryIssue) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon with background
            ZStack {
                Circle()
                    .fill(issue.color.opacity(0.12))
                    .frame(width: DesignSystem.Icon.hero, height: DesignSystem.Icon.hero)
                Image(systemName: issue.icon)
                    .font(.system(size: DesignSystem.Icon.medium, weight: .medium))
                    .foregroundColor(issue.color)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(issue.title)
                    .font(.system(.callout, design: .rounded, weight: .semibold))
                Text(issue.detail)
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if let action = issue.action, let label = issue.actionLabel {
                Button {
                    HapticFeedback.medium()
                    withAnimation(DesignSystem.Animation.standard) {
                        action()
                        showSuccessToast(label + " complete")
                    }
                } label: {
                    Text(label)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.horizontal, DesignSystem.Spacing.md + 6)
                        .padding(.vertical, DesignSystem.Spacing.sm + 4)
                        .background(
                            Capsule()
                                .fill(issue.color.gradient)
                        )
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
                .shadow(color: issue.color.opacity(0.3), radius: 4, y: 2)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                        .stroke(issue.color.opacity(0.15), lineWidth: 1)
                )
        )
        .hoverEffect()
    }

    // MARK: - Success Toast

    private var successToast: some View {
        SuccessCheckmark(message: successMessage)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(
                        Capsule()
                            .stroke(Color.green.opacity(0.25), lineWidth: 1)
                    )
            )
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation(DesignSystem.Animation.standard) { showSuccess = false }
            }
        }
    }

    // MARK: - Recoverable Space Banner

    private var recoverableBanner: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                Image(systemName: "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.0f GB Recoverable", suggestions.totalRecoverableGB))
                    .font(.system(.callout, design: .rounded, weight: .bold))
                Text("Time Machine, iOS updates, caches & more")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                HapticFeedback.medium()
                manager.freeRAM()
            } label: {
                Text("Clean")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .padding(.horizontal, DesignSystem.Spacing.md + 6)
                    .padding(.vertical, DesignSystem.Spacing.sm + 4)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
            .shadow(color: Color.blue.opacity(0.3), radius: 4, y: 2)
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.large, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
        )
        .hoverEffect()
    }

    // MARK: - Top Processes

    private var topProcesses: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text("TOP PROCESSES")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.secondary)
                .tracking(1.5)

            ForEach(manager.processMonitor.topProcesses.prefix(3)) { process in
                topProcessRow(process)
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium)
                .fill(.ultraThinMaterial)
        )
    }

    // MARK: - Smart Suggestions

    private var smartSuggestions: some View {
        SmartSuggestionsView()
    }
    
    private func topProcessRow(_ process: ProcessMemoryInfo) -> some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            if let icon = manager.processMonitor.iconForProcess(pid: process.id) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.12))
                    .frame(width: 22, height: 22)
                    .overlay(
                        Image(systemName: "app.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    )
            }

            Text(process.name)
                .font(.system(.subheadline, design: .rounded, weight: .medium))
                .lineLimit(1)

            Spacer()

            Text(String(format: "%.0f MB", process.memoryMB))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Button {
                processToKill = process
                showKillConfirmation = true
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.06))
                    )
            }
            .buttonStyle(.plain)
            .hoverEffect()
        }
        .padding(.vertical, DesignSystem.Spacing.xs)
    }

    // MARK: - Helpers

    private func showSuccessToast(_ message: String) {
        successMessage = message
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            showSuccess = true
        }
    }

    // MARK: - Issue Model

    private struct PrimaryIssue {
        let icon: String
        let title: String
        let detail: String
        let color: Color
        let actionLabel: String?
        let action: (() -> Void)?
    }

    private var primaryIssue: PrimaryIssue? {
        if devMonitor.swapUsedGB > 10 {
            return PrimaryIssue(
                icon: "arrow.triangle.2.circlepath",
                title: "Restart your Mac",
                detail: String(format: "%.1f GB of swap is slowing things down", devMonitor.swapUsedGB),
                color: .red,
                actionLabel: nil,
                action: nil
            )
        }

        if devMonitor.opencodeDBSizeMB > 500 {
            return PrimaryIssue(
                icon: "cylinder.fill",
                title: "OpenCode database is bloated",
                detail: String(format: "%.0f MB in RAM — clean to free memory", devMonitor.opencodeDBSizeMB),
                color: .red,
                actionLabel: "Clean",
                action: { devMonitor.cleanOpencodeDB() }
            )
        }

        if devMonitor.hasStandaloneSessions {
            let mb = devMonitor.opencodeProcesses.filter { $0.type == .standalone }.reduce(0.0) { $0 + $1.memoryMB }
            return PrimaryIssue(
                icon: "bolt.slash.fill",
                title: "Standalone sessions wasting memory",
                detail: String(format: "%.0f MB — use serve+attach instead", mb),
                color: .orange,
                actionLabel: "Kill",
                action: { devMonitor.killStandaloneSessions() }
            )
        }

        if let mem = systemMonitor.currentMemory, mem.usedPercentage > 85 {
            return PrimaryIssue(
                icon: "memorychip.fill",
                title: "Memory is running high",
                detail: String(format: "%.0f%% used", mem.usedPercentage),
                color: .orange,
                actionLabel: "Free RAM",
                action: { manager.freeRAM() }
            )
        }

        if devMonitor.browserTabCount > 30 {
            return PrimaryIssue(
                icon: "macwindow.on.rectangle",
                title: "Too many browser tabs",
                detail: "\(devMonitor.browserTabCount) tabs using \(String(format: "%.0f MB", devMonitor.browserTotalMB))",
                color: .orange,
                actionLabel: nil,
                action: nil
            )
        }

        return nil
    }

    // MARK: - Computed

    private var statusSentence: String {
        if let issue = primaryIssue { return issue.title }
        return "Your Mac is healthy."
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

    private var memoryUsedGB: Double { systemMonitor.currentMemory?.usedGB ?? 0 }
    private var memoryTotalGB: Double { systemMonitor.currentMemory?.totalGB ?? 18 }

    private var memoryPercentText: String {
        if let mem = systemMonitor.currentMemory { return String(format: "%.0f%%", mem.usedPercentage) }
        return "—"
    }

    private var memoryColor: Color {
        guard let mem = systemMonitor.currentMemory else { return .gray }
        return mem.usedPercentage > 85 ? .red : mem.usedPercentage > 75 ? .orange : .green
    }

    private var memoryPercent: Double { systemMonitor.currentMemory?.usedPercentage ?? 0 }

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

    private var browserPercent: Double {
        min(devMonitor.browserTotalMB / 4000 * 100, 100)
    }
}

#Preview {
    HealthView()
        .frame(width: 700, height: 600)
}