import SwiftUI

/// Premium menu bar popover — The Orb. One glance, one action, alive.
struct MenuBarLiteView: View {
    @ObservedObject var manager: MemoryMonitorManager
    @ObservedObject var devMonitor = DeveloperMonitor.shared
    @ObservedObject var tempMonitor = TemperatureMonitor.shared
    @State private var animateGauges = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            // The Orb — the centerpiece
            VitalityOrb(
                healthScore: manager.healthScore,
                memoryPercent: memoryPercent,
                cpuPercent: cpuPercent
            )
            .padding(.top, DesignSystem.Spacing.lg)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Status sentence
            Text(statusSentence)
                .font(DesignSystem.Typography.subheadline)
                .foregroundColor(.primary)
                .padding(.bottom, DesignSystem.Spacing.xs)

            Text(String(format: "%.1f GB of %.0f GB", memoryUsedGB, memoryTotalGB))
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, DesignSystem.Spacing.md)

            // Horizontal stats bar with icon + value pairs
            HStack {
                StatBlock(icon: "memorychip", value: memoryValue, color: memoryColor)
                StatBlock(icon: "externaldrive", value: String(format: "%.1f", devMonitor.swapUsedGB), color: swapColor)
                StatBlock(icon: "cpu", value: cpuValue, color: cpuColor)

                // Only show temp if it's detected (>0)
                if tempMonitor.maxTemperature > 0 {
                    StatBlock(icon: "thermometer", value: String(format: "%.0f°", tempMonitor.maxTemperature), color: Color.temperature(tempMonitor.maxTemperature))
                } else {
                    // Placeholder to maintain consistent layout
                    HStack(spacing: 2) {
                        Image(systemName: "thermometer")
                            .font(.system(size: DesignSystem.Icon.small))
                            .foregroundColor(.secondary)
                        Text("--°")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: 60)
                    .fixedSize()
                }
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.bottom, DesignSystem.Spacing.md)

            // Optimize button — always visible, shimmer when working
            optimizeButton

            // Stop Memory Hog button - shows top memory consumer
            stopMemoryHogSection

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
        .overlay(
            // Show confirmation dialog when needed in menu bar
            Group {
                if manager.optimizer.showCleanupConfirmation {
                    ConfirmationDialogOverlay()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.5))
                }
            }
        )
        .animation(DesignSystem.Animation.standard, value: manager.optimizer.isWorking)
        .animation(DesignSystem.Animation.standard, value: manager.optimizer.lastResult?.timestamp)
        .onAppear {
            devMonitor.start()
            tempMonitor.startMonitoring()
            withAnimation(DesignSystem.Animation.entrance.delay(0.1)) { animateGauges = true }
        }
        .onDisappear { 
            tempMonitor.stopMonitoring()
        }
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
    
    // MARK: - Confirmation Dialog Overlay (for Menu Bar)

    private func ConfirmationDialogOverlay() -> some View {
        VStack {
            Spacer()
            ZStack {
                Color.black.opacity(0.5)
                    .ignoresSafeArea()

                // Safety-enhanced confirmation dialog
                VStack(spacing: 0) {
                    // Header
                    headerSection

                    Divider()

                    // Content - either itemized list or redirect warning
                    if manager.optimizer.requiresReview {
                        reviewRequiredSection
                    } else {
                        itemizedListSection
                    }

                    Divider()

                    // Action buttons
                    actionButtons
                }
                .frame(maxWidth: 320)
                .frame(maxHeight: 380)
                .background(Color(nsColor: .windowBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
            }
        }
    }

    // MARK: - Dialog Sections

    private var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "shield.checkered")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Review Cleanup Items")
                    .font(.system(size: 14, weight: .bold, design: .rounded))

                if let plan = manager.optimizer.pendingCleanupPlan {
                    Text("\(plan.itemCount) items · \(plan.totalSizeText)")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                if manager.optimizer.requiresExplicitConfirmation {
                    Text("Large cleanup requires extra confirmation")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.orange)
                }
            }

            Spacer()
        }
        .padding(14)
    }

    private var reviewRequiredSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 32))
                .foregroundStyle(.orange)
                .padding(.top, 20)

            Text("Large Cleanup Detected")
                .font(.system(size: 14, weight: .semibold, design: .rounded))

            Text("This cleanup is \(manager.optimizer.pendingCleanupPlan?.totalSizeText ?? "large"). For safety, please review in the Dashboard.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button {
                manager.optimizer.cancelCleanup()
                NavigationManager.shared.navigate(to: .dashboard)
            } label: {
                HStack {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("Open Dashboard")
                }
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.gradient)
                .foregroundColor(.white)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }

    private var itemizedListSection: some View {
        ScrollView {
            VStack(spacing: 8) {
                // Safe to clean section only - MenuBarLite is for quick, safe operations
                // Review/destructive items are only shown in the full Dashboard
                if !manager.optimizer.safeItems.isEmpty {
                    sectionHeader("Safe to Clean", icon: "checkmark.shield.fill", color: .green)

                    ForEach(manager.optimizer.safeItems) { item in
                        cleanupItemRow(item)
                    }
                }

                // Show indicator if review items exist but aren't shown (for transparency)
                if manager.optimizer.hasReviewItems {
                    HStack(spacing: 6) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 10))
                        Text("More items available in Dashboard")
                            .font(.system(size: 10, design: .rounded))
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .padding(12)
        }
    }

    private func sectionHeader(_ title: String, icon: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(color)

            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(color)

            Spacer()

            Text(toggleLabel(for: title))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.secondary)
                .onTapGesture {
                    if title.contains("Safe") {
                        manager.optimizer.selectAllSafe()
                    } else {
                        // For review items, don't auto-select
                    }
                }
        }
    }

    private func toggleLabel(for section: String) -> String {
        if section.contains("Safe") {
            return "Select All"
        }
        return "Manual"
    }

    private func cleanupItemRow(_ item: ComprehensiveOptimizer.CleanupPlan.CleanupItem) -> some View {
        let isSelected = manager.optimizer.selectedItemIds.contains(item.id)

        return HStack(spacing: 10) {
            // Checkbox
            Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                .onTapGesture {
                    manager.optimizer.toggleSelection(item.id)
                }

            // Category icon
            categoryIcon(for: item.category)
                .font(.system(size: 12))
                .frame(width: 16)

            // Name and details
            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .lineLimit(1)

                if let appName = item.appName {
                    Text("Requires \(appName) closed")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.orange)
                } else if let warning = item.warningMessage {
                    Text(warning)
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(.orange)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Size
            Text(formatSize(item.sizeMB))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(sizeColor(for: item.sizeMB))
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.02))
        )
    }

    private func categoryIcon(for category: OptimizeResult.Category) -> some View {
        let (icon, color): (String, Color) = {
            switch category {
            case .developer: return ("terminal.fill", .purple)
            case .browser: return ("globe", .blue)
            case .system: return ("gearshape.fill", .green)
            case .application: return ("app.fill", .cyan)
            case .memory: return ("memorychip", .orange)
            case .disk: return ("externaldrive.fill", .red)
            case .logs: return ("doc.text.fill", .yellow)
            }
        }()

        return Image(systemName: icon)
            .foregroundStyle(color)
    }

    private func formatSize(_ mb: Double) -> String {
        if mb > 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    private func sizeColor(for mb: Double) -> Color {
        if mb > 10 * 1024 { return .red }
        if mb > 5 * 1024 { return .orange }
        return .secondary
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button("Cancel") {
                manager.optimizer.cancelCleanup()
            }
            .buttonStyle(.bordered)
            .tint(.secondary)

            Spacer()

            // Show selected count
            if manager.optimizer.selectedTotalSizeMB > 0 {
                Text("\(formatSize(manager.optimizer.selectedTotalSizeMB))")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            Button {
                // Execute cleanup - will use selectedItemIds
                manager.optimizer.showCleanupConfirmation = false
                manager.optimizer.executeCleanup()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "trash.fill")
                        .font(.system(size: 10))
                    Text("Clean Selected")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(manager.optimizer.requiresExplicitConfirmation ? .red : .green)
            .disabled(manager.optimizer.selectedItemIds.isEmpty)
        }
        .padding(12)
    }

    // MARK: - Stop Memory Hog Section

    @State private var showingStopConfirmation = false

    private var stopMemoryHogSection: some View {
        Group {
            if let topProcess = manager.processMonitor.topProcesses.first {
                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Memory Hog")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(topProcess.name)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        Text(String(format: "%.1f GB", topProcess.memoryGB))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.orange)
                    }

                    Spacer()

                    Button {
                        showingStopConfirmation = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                            Text("Stop")
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.15))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("Stop \(topProcess.name)?", isPresented: $showingStopConfirmation) {
                        Button("Stop Process", role: .destructive) {
                            AutoKillManager.shared.killProcess(
                                pid: topProcess.id,
                                name: topProcess.name,
                                reason: "Manual stop from menu bar",
                                memoryGB: topProcess.memoryGB
                            )
                            HapticFeedback.medium()
                        }
                        Button("Cancel", role: .cancel) { }
                    } message: {
                        Text("This will close \(topProcess.name) and free \(String(format: "%.1f", topProcess.memoryGB)) GB of memory.")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Optimize Button

    /// Computed property for contextual CTA text
    private var contextualButtonText: String {
        if manager.optimizer.isWorking {
            return manager.optimizer.statusMessage.isEmpty ? "Working..." : manager.optimizer.statusMessage
        }

        // Show freed amount if we have a recent result (within last 10 seconds)
        if let result = manager.optimizer.lastResult,
           Date().timeIntervalSince(result.timestamp) < 10 {
            return result.summary
        }

        // Show "Review Items" if there are review items present
        if manager.optimizer.hasReviewItems {
            return "Review Items"
        }

        // Show safe total size for quick clean (MenuBarLite only does safe items)
        let safeSize = manager.optimizer.safeTotalSizeMB
        if safeSize > 0 {
            return "Free \(formatSize(safeSize))"
        }

        // Default to quick clean
        return "Quick Clean"
    }

    /// Whether to show the right arrow (not showing during work or recent result)
    private var showButtonArrow: Bool {
        !manager.optimizer.isWorking &&
        (manager.optimizer.lastResult == nil ||
         Date().timeIntervalSince(manager.optimizer.lastResult?.timestamp ?? Date.distantPast) > 10)
    }

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
                        // Show current progress step
                        Text(statusMessageForDisplay)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: DesignSystem.Icon.tiny, weight: .bold))
                        Text(contextualButtonText)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        if showButtonArrow {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .bold))
                                .opacity(0.7)
                        }
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

    /// Status message cleaned up for display (remove emojis for menu bar)
    private var statusMessageForDisplay: String {
        let raw = manager.optimizer.statusMessage
        // Clean up emoji prefixes for cleaner look in menu bar
        return raw
            .replacingOccurrences(of: "💻 ", with: "")
            .replacingOccurrences(of: "🌐 ", with: "")
            .replacingOccurrences(of: "⚙️ ", with: "")
            .replacingOccurrences(of: "💾 ", with: "")
            .replacingOccurrences(of: "🧠 ", with: "")
    }
    
    private func timeAgo(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 5 { return "just now" }
        if interval < 60 { return "\(Int(interval))s ago" }
        if interval < 3600 { return "\(Int(interval / 60))m ago" }
        return "\(Int(interval / 3600))h ago"
    }
    
    // MARK: - Result Banner

    private func resultBanner(_ result: OptimizeResult) -> some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Animated success checkmark
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DesignSystem.Icon.medium, weight: .medium))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: result.timestamp)

            VStack(alignment: .leading, spacing: 2) {
                // Amount freed prominently
                Text(result.totalFreedMB > 1024
                     ? String(format: "%.1f GB freed", result.totalFreedMB / 1024)
                     : String(format: "%.0f MB freed", result.totalFreedMB))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)

                // Categories affected (if any)
                if !result.steps.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(categoryIcons(from: result.steps), id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                        if result.successCount > 0 {
                            Text("\(result.successCount) actions")
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(DesignSystem.Spacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.medium, style: .continuous)
                .fill(.green.opacity(0.1))
        )
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.bottom, DesignSystem.Spacing.sm)
    }

    /// Extract category icons from steps
    private func categoryIcons(from steps: [OptimizeResult.Step]) -> [String] {
        var icons = Set<String>()
        for step in steps where step.success {
            if let category = step.category {
                icons.insert(iconForCategory(category))
            }
        }
        return Array(icons).prefix(3).map { $0 }
    }

    private func iconForCategory(_ category: OptimizeResult.Category) -> String {
        switch category {
        case .developer: return "chevron.left.forwardslash.chevron.right"
        case .browser: return "globe"
        case .application: return "app.fill"
        case .system: return "gearshape.fill"
        case .memory: return "memorychip"
        case .disk: return "externaldrive.fill"
        case .logs: return "doc.text.fill"
        }
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

    // MARK: - Stat Block Component

    private func StatBlock(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(color)
        }
        .frame(maxWidth: 60)
        .fixedSize()
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
