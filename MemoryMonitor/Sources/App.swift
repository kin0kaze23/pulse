import SwiftUI
import UserNotifications

// MARK: - Adaptive Menu Bar Content (switches between lite and full)

struct MenuBarAdaptiveContent: View {
    @ObservedObject var manager: MemoryMonitorManager
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        if settings.liteMode {
            MenuBarLiteView(manager: manager)
        } else {
            MenuBarPopoverContent(manager: manager)
                .frame(width: 320)
        }
    }
}

@main
struct PulseApp: App {
    @StateObject private var manager = MemoryMonitorManager.shared
    @StateObject private var settings = AppSettings.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // Dashboard window — primary window, opens on launch
        WindowGroup("Pulse", id: "main") {
            ZStack {
                DashboardView()
                    .environmentObject(manager)
                    .onAppear { manager.start() }
                    .frame(minWidth: 850, minHeight: 620)
                
                // Cleanup Confirmation Overlay
                if manager.optimizer.showCleanupConfirmation {
                    CleanupConfirmationView()
                        .environmentObject(manager)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Action Toast (shows during/after optimization)
                VStack {
                    Spacer()
                    ActionToastView()
                        .padding(.bottom, 20)
                        .padding(.horizontal, 20)
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.8), value: manager.optimizer.showCleanupConfirmation)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 650)

        // Settings window
        Window("Settings", id: "settings") {
            SettingsView()
                .environmentObject(manager)
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 500, height: 440)

        // Menu bar extra — always visible, content adapts to lite mode
        MenuBarExtra {
            MenuBarAdaptiveContent(manager: manager)
        } label: {
            MenuBarLabel(manager: manager)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar app — use accessory policy (no Dock icon, stays running)
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate()

        // Request notification authorization
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }

        // Open window on main screen after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showMainWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Keep running in menu bar
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Don't call showMainWindow here — causes double-show on every focus
        // Window is already shown in applicationDidFinishLaunching
    }

    private func showMainWindow() {
        for window in NSApp.windows {
            if window.title.contains("Pulse") {
                // Force to main screen
                if let mainScreen = NSScreen.main {
                    let screenFrame = mainScreen.visibleFrame
                    let windowSize = window.frame.size
                    let x = screenFrame.midX - windowSize.width / 2
                    let y = screenFrame.midY - windowSize.height / 2
                    window.setFrameOrigin(NSPoint(x: x, y: y))
                }
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Menu Bar Label

struct MenuBarLabel: View {
    @ObservedObject var manager: MemoryMonitorManager
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: manager.menuBarIcon)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(pressureColor)
                .font(.system(size: 13, weight: .semibold))

            if settings.menuBarDisplayMode == .compact {
                // Compact mode: show both Memory % and CPU %
                HStack(spacing: 3) {
                    Text(memText)
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(cpuText)
                }
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(pressureColor)
            } else {
                Text(manager.menuBarText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(pressureColor)
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
    }
    
    private var memText: String {
        guard let memory = manager.systemMonitor.currentMemory else { return "--%" }
        return String(format: "%.0f%%", memory.usedPercentage)
    }
    
    private var cpuText: String {
        let cpu = manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage
        return String(format: "%.0f%%", cpu)
    }

    private var pressureColor: Color {
        switch manager.systemMonitor.pressureLevel {
        case .normal: return .primary
        case .warning: return .orange
        case .critical: return .red
        }
    }
}

// MARK: - Menu Bar Popover

struct MenuBarPopoverContent: View {
    @ObservedObject var manager: MemoryMonitorManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: Health score
            healthHeader

            Divider().padding(.vertical, 8)

            // Memory + CPU quick stats
            quickStatsSection

            Divider().padding(.vertical, 8)

            // Top 3 processes
            topProcessesSection

            Divider().padding(.vertical, 8)

            // Network speed
            networkSection

            Divider().padding(.vertical, 8)

            // Recommendations
            if !manager.recommendations.isEmpty {
                recommendationsSection
                Divider().padding(.vertical, 8)
            }

            // Actions
            actionsSection
        }
        .padding(12)
    }

    // MARK: - Health Header

    private var healthHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(manager.healthScore) / 100.0)
                    .stroke(scoreColor.gradient, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(manager.healthGrade)
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(scoreColor)
                }
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("Mac Health")
                    .font(.system(.body, weight: .semibold))
                Text("Score: \(manager.healthScore)/100")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(Date.now, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Battery
            VStack(spacing: 2) {
                Image(systemName: batteryIcon)
                    .foregroundColor(batteryColor)
                Text(String(format: "%.0f%%", manager.healthMonitor.batteryPercentage))
                    .font(.system(.caption2, design: .rounded, weight: .medium))
            }
        }
    }

    // MARK: - Quick Stats

    private var quickStatsSection: some View {
        HStack(spacing: 8) {
            if let memory = manager.systemMonitor.currentMemory {
                MiniStatCard(
                    icon: "memorychip",
                    label: "Memory",
                    value: String(format: "%.0f%%", memory.usedPercentage),
                    detail: String(format: "%.1f GB", memory.usedGB),
                    color: memory.usedPercentage > 85 ? .red : memory.usedPercentage > 75 ? .orange : .green
                )
            }

            MiniStatCard(
                icon: "cpu",
                label: "CPU",
                value: String(format: "%.0f%%", manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage),
                detail: "\(manager.cpuMonitor.coreCount) cores",
                color: (manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage) > 80 ? .red :
                    (manager.cpuMonitor.userCPUPercentage + manager.cpuMonitor.systemCPUPercentage) > 50 ? .orange : .green
            )

            if let disk = manager.diskMonitor.primaryDisk {
                MiniStatCard(
                    icon: "internaldrive",
                    label: "Disk",
                    value: String(format: "%.0f%%", disk.usedPercentage),
                    detail: String(format: "%.0f GB free", disk.freeGB),
                    color: disk.usedPercentage > 90 ? .red : disk.usedPercentage > 75 ? .orange : .green
                )
            }
        }
    }

    // MARK: - Top Processes

    private var topProcessesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top Memory Hogs")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            ForEach(manager.processMonitor.topProcesses.prefix(3)) { process in
                HStack(spacing: 8) {
                    if let icon = manager.processMonitor.iconForProcess(pid: process.id) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "app.fill")
                            .frame(width: 16, height: 16)
                            .foregroundColor(.gray)
                    }

                    Text(process.name)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)

                    Spacer()

                    Text(String(format: "%.0f MB", process.memoryMB))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Network

    private var networkSection: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.caption2)
                    .foregroundColor(.blue)
                Text(String(format: "%.1f MB/s", manager.healthMonitor.downloadSpeed))
                    .font(.system(.caption, design: .monospaced))
            }
            HStack(spacing: 4) {
                Image(systemName: "arrow.up")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text(String(format: "%.1f MB/s", manager.healthMonitor.uploadSpeed))
                    .font(.system(.caption, design: .monospaced))
            }
            Spacer()
            Text("Network")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tips")
                .font(.caption.bold())
                .foregroundColor(.secondary)

            ForEach(Array(manager.recommendations.prefix(2).enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 4) {
                    Image(systemName: tip.contains("well") ? "checkmark.circle.fill" : "lightbulb.fill")
                        .font(.caption2)
                        .foregroundColor(tip.contains("well") ? .green : .yellow)
                    Text(tip)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - Actions

    private var actionsSection: some View {
        VStack(spacing: 2) {
            Button {
                manager.freeRAM()
            } label: {
                if manager.optimizer.isWorking {
                    HStack {
                        ProgressView()
                            .controlSize(.small)
                        Text("Optimizing...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    Label("Optimize Now", systemImage: "bolt.fill")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .disabled(manager.optimizer.isWorking)

            // Show last result
            if let result = manager.optimizer.lastResult,
               Date().timeIntervalSince(result.timestamp) < 8 {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text(result.summary)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }

            Divider().padding(.vertical, 2)

            Button {
                NSApp.activate()
                openWindow(id: "main")
            } label: {
                Label("Open Dashboard", systemImage: "square.grid.2x2")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("d")

            Button {
                openWindow(id: "settings")
            } label: {
                Label("Settings...", systemImage: "gear")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut(",")

            Divider().padding(.vertical, 2)

            Button(role: .destructive) {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("Quit", systemImage: "power")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .keyboardShortcut("q")
        }
        .buttonStyle(.plain)
        .font(.system(.caption, weight: .medium))
    }

    // MARK: - Helpers

    private var scoreColor: Color {
        DesignSystem.Colors.score(manager.healthScore)
    }

    private var batteryIcon: String {
        let pct = manager.healthMonitor.batteryPercentage
        if manager.healthMonitor.isCharging { return "battery.100.bolt" }
        if pct > 75 { return "battery.100" }
        if pct > 50 { return "battery.75" }
        if pct > 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryColor: Color {
        DesignSystem.Colors.battery(manager.healthMonitor.batteryPercentage, isCharging: manager.healthMonitor.isCharging)
    }
}

// MARK: - Mini Stat Card

struct MiniStatCard: View {
    let icon: String
    let label: String
    let value: String
    let detail: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)

            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundColor(color)
                .contentTransition(.numericText())

            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(detail)
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(.secondary)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(color.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
