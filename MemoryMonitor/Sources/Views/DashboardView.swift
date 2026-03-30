import SwiftUI

/// Main dashboard — tabs: Health, Memory, Developer, Security, More, Settings
/// Premium implementation with consistent design system and micro-interactions
struct DashboardView: View {
    @ObservedObject var manager = MemoryMonitorManager.shared
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedTab: Tab = .health
    @State private var isViewVisible = false
    @State private var showOnboarding = false
    @Environment(\.openWindow) private var openWindow

    enum Tab: String, CaseIterable {
        case health = "Health"
        case memory = "Memory"
        case system = "System"
        case caches = "Caches"
        case optimizer = "Optimizer"
        case developer = "Developer"
        case security = "Security"
        case history = "History"
        case diskexplorer = "Disk Explorer"

        var icon: String {
            switch self {
            case .health: return "heart.text.square.fill"
            case .memory: return "memorychip"
            case .system: return "cpu"
            case .caches: return "externaldrive.fill"
            case .optimizer: return "sparkles"
            case .developer: return "terminal.fill"
            case .security: return "shield.checkered"
            case .history: return "chart.xyaxis.line"
            case .diskexplorer: return "internaldrive"
            }
        }
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                topBar
                    .staggeredEntrance(delay: 0)
                Divider()
                HStack(spacing: 0) {
                    sidebar
                        .staggeredEntrance(delay: 0.05)
                    Divider()
                    ScrollView {
                        contentSection
                            .padding(DesignSystem.Spacing.lg)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(minWidth: 800, idealWidth: 900, minHeight: 600, idealHeight: 650)
            .background(Color(nsColor: .windowBackgroundColor))

            // Onboarding overlay
            if showOnboarding {
                OnboardingPermissionView {
                    withAnimation(DesignSystem.Animation.standard) {
                        showOnboarding = false
                    }
                }
                .transition(.opacity)
            }

            // Permission change toast (global, visible in all tabs)
            VStack {
                Spacer()
                if permissionsToastVisible {
                    permissionChangeToast
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            withAnimation(DesignSystem.Animation.entrance) {
                isViewVisible = true
            }

            // Show onboarding on first launch ONLY
            // Use DispatchQueue to ensure settings are fully loaded
            if !settings.hasSeenPermissionOnboarding && !showOnboarding {
                showOnboarding = true
            }
        }
        .onChange(of: PermissionsService.shared.permissionsChanged) { _, changed in
            if changed {
                permissionsToastVisible = true
                // Auto-dismiss after 4 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    withAnimation {
                        permissionsToastVisible = false
                    }
                }
            }
        }
    }

    @State private var permissionsToastVisible = false

    private var permissionChangeToast: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            // Icon based on whether permission was granted or revoked
            Image(systemName: PermissionsService.shared.recentChange?.wasGranted == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(PermissionsService.shared.recentChange?.wasGranted == true ? .green : .orange)

            VStack(alignment: .leading, spacing: 2) {
                // Specific message about what changed
                if let change = PermissionsService.shared.recentChange {
                    Text("\(change.type.rawValue) \(change.wasGranted ? "granted" : "revoked")")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(change.wasGranted ? "Feature limitations lifted" : "Some features may now be limited")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                } else {
                    Text("Permission status updated")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Text("Changes detected — some features may now be available")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(DesignSystem.Radius.medium)
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Brand with health score and trend
            HStack(spacing: DesignSystem.Spacing.sm) {
                ZStack {
                    Circle()
                        .stroke(Color.primary.opacity(0.08), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: CGFloat(manager.healthScore) / 100.0)
                        .stroke(scoreColor.gradient, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(DesignSystem.Animation.emphasis, value: manager.healthScore)
                    Text(manager.healthGrade)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(Brand.name)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    // 7-day trend indicator
                    if let result = manager.healthScoreService.currentResult,
                       let delta7d = result.delta7d,
                       result.trend7d != .insufficientData {
                        let trend7d = result.trend7d
                        HStack(spacing: 2) {
                            Image(systemName: trend7d.compactIcon)
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(Color(trend7d.color))
                            Text("\(trend7d.signFor(delta: delta7d))\(delta7d)")
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(trend7d.color))
                            Text("7d")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Collecting trend data...")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Optimize button — premium style
            Button {
                HapticFeedback.medium()
                manager.freeRAM()
            } label: {
                if manager.optimizer.isWorking {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Optimizing...")
                            .font(DesignSystem.Typography.caption)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Optimize")
                            .font(DesignSystem.Typography.caption)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.accentColor.gradient)
            )
            .foregroundColor(.white)
            .shadow(color: Color.accentColor.opacity(0.25), radius: 3, y: 1)
            .disabled(manager.optimizer.isWorking)
            .scaleEffect(manager.optimizer.isWorking ? 1.0 : 1.0)
            .animation(DesignSystem.Animation.micro, value: manager.optimizer.isWorking)

            // Refresh
            Button {
                HapticFeedback.light()
                manager.processMonitor.refresh(topN: manager.settings.topProcessesCount)
                manager.systemMonitor.updateMemoryInfo()
                manager.cpuMonitor.update()
                manager.diskMonitor.refresh()
                manager.healthMonitor.update()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(
                Circle()
                    .fill(Color.primary.opacity(0.06))
            )
            .foregroundColor(.secondary)
            .hoverEffect()
            
            // Settings button
            Button {
                openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .padding(6)
            .background(
                Circle()
                    .fill(Color.primary.opacity(0.06))
            )
            .foregroundColor(.secondary)
            .hoverEffect()
            .keyboardShortcut(",", modifiers: .command)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Tab.allCases, id: \.self) { tab in
                sidebarTab(tab)
            }

            Spacer()

            // Battery
            BatteryStatusView(
                percentage: manager.healthMonitor.batteryPercentage,
                isCharging: manager.healthMonitor.isCharging
            )
            .padding(.top, DesignSystem.Spacing.sm)
        }
        .padding(.vertical, DesignSystem.Spacing.md)
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .frame(width: 80)
        .background(.ultraThinMaterial)
    }

    private func sidebarTab(_ tab: Tab) -> some View {
        Button {
            HapticFeedback.light()
            withAnimation(DesignSystem.Animation.standard) { selectedTab = tab }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: selectedTab == tab ? .semibold : .regular))
                    .contentTransition(.symbolEffect(.replace))
                Text(tab.rawValue)
                    .font(.system(size: 9, weight: selectedTab == tab ? .semibold : .regular, design: .rounded))
            }
            .frame(width: 68)
            .padding(.vertical, DesignSystem.Spacing.sm)
            .foregroundColor(selectedTab == tab ? .white : .secondary)
            .background(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.small)
                    .fill(selectedTab == tab ? Color.accentColor : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .health:
            HealthView()
                .staggeredEntrance(delay: 0.1)
        case .memory:
            MemorySection()
                .staggeredEntrance(delay: 0.1)
        case .system:
            SystemView()
                .staggeredEntrance(delay: 0.1)
        case .caches:
            PackageManagerCachesView()
                .staggeredEntrance(delay: 0.1)
        case .optimizer:
            OptimizerView()
                .staggeredEntrance(delay: 0.1)
        case .developer:
            DeveloperView()
                .staggeredEntrance(delay: 0.1)
        case .security:
            SecurityView()
                .staggeredEntrance(delay: 0.1)
        case .history:
            HistoryChartsView()
                .staggeredEntrance(delay: 0.1)
        case .diskexplorer:
            DiskExplorerView()
                .staggeredEntrance(delay: 0.1)
        }
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        DesignSystem.Colors.score(manager.healthScore)
    }

    private func openSettingsWindow() {
        // Open the settings window using SwiftUI's openWindow environment
        openWindow(id: "settings")
    }
}

// MARK: - Quick Stat Pill

struct QuickStatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, DesignSystem.Spacing.sm)
        .padding(.vertical, DesignSystem.Spacing.xs)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Memory Section

struct MemorySection: View {
    @ObservedObject var systemMonitor = SystemMemoryMonitor.shared

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            sectionHeader
            
            if let memory = systemMonitor.currentMemory {
                HStack(spacing: DesignSystem.Spacing.lg) {
                    MemoryGaugeView(
                        percentage: memory.usedPercentage,
                        pressureLevel: systemMonitor.pressureLevel,
                        size: 140
                    )

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        QuickStatRow(label: "Used", value: String(format: "%.2f GB", memory.usedGB), color: .blue)
                        QuickStatRow(label: "Free", value: String(format: "%.2f GB", memory.freeGB), color: .green)
                        QuickStatRow(label: "Cached", value: String(format: "%.2f GB", memory.cachedGB), color: .gray)
                        QuickStatRow(label: "Compressed", value: String(format: "%.2f GB", memory.compressedGB), color: .cyan)
                        QuickStatRow(label: "Wired", value: String(format: "%.2f GB", memory.wiredGB), color: .purple)
                        QuickStatRow(label: "Swap", value: String(format: "%.2f GB", memory.swapUsedGB), color: .orange)
                    }
                    Spacer()
                }

                MemoryBreakdownView(memory: memory)
            }

            MemoryHistoryView()
        }
    }
    
    private var sectionHeader: some View {
        HStack {
            Image(systemName: "memorychip")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 2) {
                Text("Memory")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                Text("Detailed memory breakdown and history")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
}

struct QuickStatRow: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .font(DesignSystem.Typography.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(DesignSystem.Typography.caption)
                .fontWeight(.semibold)
        }
        .frame(minWidth: 180)
    }
}

#Preview {
    DashboardView()
}
