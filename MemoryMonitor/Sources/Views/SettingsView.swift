import SwiftUI

/// Settings/preferences panel
struct SettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general = "General"
        case cleanup = "Cleanup"
        case stats = "Stats"
        case alerts = "Alerts"
        case display = "Display"
        case guard_ = "Guard"
        case automation = "Automation"
        case permissions = "Permissions"
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            VStack(spacing: 2) {
                ForEach(SettingsTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        HStack {
                            Image(systemName: icon(for: tab))
                                .frame(width: 16)
                            Text(tab.rawValue)
                            Spacer()
                        }
                        .foregroundColor(selectedTab == tab ? .white : .primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(selectedTab == tab ? Color.accentColor : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(8)
            .frame(width: 140)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))

            Divider()

            // Content
            ScrollView {
                contentSection
                    .padding(16)
            }
        }
        .frame(width: 520, height: 460)
        .onAppear {
            // Listen for notification to open permissions tab
            NotificationCenter.default.addObserver(
                forName: .openSettingsToPermissions,
                object: nil,
                queue: .main
            ) { _ in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    selectedTab = .permissions
                }
            }
        }
    }

    @ViewBuilder
    private var contentSection: some View {
        switch selectedTab {
        case .general: GeneralSettingsContent()
        case .cleanup: CleanupSettingsContent()
        case .stats: StatsSettingsContent()
        case .alerts: AlertSettingsContent()
        case .display: DisplaySettingsContent()
        case .guard_: GuardSettingsContent()
        case .automation: AutomationSettingsContent()
        case .permissions: PermissionsDiagnosticsView()
        }
    }

    private func icon(for tab: SettingsTab) -> String {
        switch tab {
        case .general: return "gear"
        case .cleanup: return "trash.circle"
        case .stats: return "chart.bar"
        case .alerts: return "bell"
        case .display: return "paintbrush"
        case .guard_: return "shield"
        case .automation: return "clock.badge.checkmark"
        case .permissions: return "lock.shield"
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsContent: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General").font(.title2.bold())

            GroupBox("Monitoring") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Refresh Interval")
                        Spacer()
                        Text(String(format: "%.1fs", settings.refreshInterval))
                            .foregroundColor(.secondary)
                            .frame(width: 50)
                    }
                    Slider(value: $settings.refreshInterval, in: 1...10, step: 0.5)
                        .help("How often to update memory stats (lower = more frequent)")

                    Toggle("Show in Menu Bar", isOn: $settings.showInMenuBar)
                        .help("Show Pulse in menu bar")

                    Toggle("Lite Mode (minimal menu bar)", isOn: $settings.liteMode)
                        .help("Reduces menu bar popover to just memory % and top process. Less CPU overhead.")

                    HStack {
                        Text("Menu Bar Display")
                        Spacer()
                        Picker("", selection: $settings.menuBarDisplayMode) {
                            ForEach(AppSettings.MenuBarDisplayMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 140)
                    }
                    .help("Choose what information is shown in the menu bar icon")

                    Toggle("Launch at Login", isOn: $settings.launchAtLogin)
                        .help("Start Pulse automatically when you turn on your Mac")
                }
                .padding(8)
            }

            GroupBox("Data") {
                VStack(alignment: .leading, spacing: 10) {
                    Stepper("Top Processes: \(settings.topProcessesCount)",
                            value: $settings.topProcessesCount, in: 5...50, step: 5)

                    Picker("Memory Unit", selection: $settings.memoryUnit) {
                        ForEach(AppSettings.MemoryUnit.allCases, id: \.self) { unit in
                            Text(unit.rawValue).tag(unit)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Cleanup Settings

struct CleanupSettingsContent: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var newWhitelistPath: String = ""
    @State private var showingPathPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup Settings").font(.title2.bold())

            GroupBox("Xcode Cleanup") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Clean Xcode DerivedData", isOn: $settings.cleanXcodeDerivedData)
                        .help("Cleans Xcode build intermediates and index data. Safe to delete - Xcode will rebuild automatically.")

                    Toggle("Clean Xcode Device Support", isOn: $settings.cleanXcodeDeviceSupport)
                        .help("Cleans old iOS device support files. Only removes support for iOS versions you haven't used recently.")

                    Text("Xcode cleanup can reclaim 5-80+ GB of space.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            GroupBox("Whitelisted Paths") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("These paths will never be cleaned:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if settings.whitelistedPaths.isEmpty {
                        Text("No whitelisted paths")
                            .font(.system(.caption, design: .rounded))
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        FlowLayout(spacing: 4) {
                            ForEach(settings.whitelistedPaths, id: \.self) { path in
                                WhitelistPathChip(path: path) {
                                    removeWhitelistPath(path)
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        TextField("Add path...", text: $newWhitelistPath)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.caption, design: .monospaced))

                        Button {
                            showingPathPicker = true
                        } label: {
                            Image(systemName: "folder")
                        }
                        .fileImporter(
                            isPresented: $showingPathPicker,
                            allowedContentTypes: [.directory],
                            allowsMultipleSelection: false
                        ) { result in
                            if case .success(let urls) = result, let url = urls.first {
                                let path = url.path
                                if !settings.whitelistedPaths.contains(path) {
                                    settings.whitelistedPaths.append(path)
                                }
                            }
                        }

                        Button {
                            addWhitelistPath()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                        }
                        .disabled(newWhitelistPath.isEmpty)
                    }
                }
                .padding(8)
            }

            GroupBox("Safety Info") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Dry-run mode: You'll always see what will be cleaned")
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Running apps: Browser/Xcode caches are skipped if running")
                            .font(.caption)
                    }
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Whitelist: Protected paths are never deleted")
                            .font(.caption)
                    }
                }
                .padding(8)
            }
        }
    }

    private func addWhitelistPath() {
        let path = newWhitelistPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty && !settings.whitelistedPaths.contains(path) {
            settings.whitelistedPaths.append(path)
            newWhitelistPath = ""
        }
    }

    private func removeWhitelistPath(_ path: String) {
        settings.whitelistedPaths.removeAll { $0 == path }
    }
}

struct WhitelistPathChip: View {
    let path: String
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "folder.fill")
                .font(.caption2)
                .foregroundColor(.blue)
            Text(shortPath)
                .font(.system(size: 10, design: .monospaced))
                .lineLimit(1)
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.1))
        .clipShape(Capsule())
    }

    private var shortPath: String {
        let components = path.components(separatedBy: "/")
        if components.count > 3 {
            return "~/" + components.suffix(2).joined(separator: "/")
        }
        return path
    }
}

// MARK: - Automation Settings

struct AutomationSettingsContent: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automation").font(.title2.bold())

            // Scheduled Cleanup
            GroupBox("Scheduled Cleanup") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable daily cleanup", isOn: $settings.dailyCleanupEnabled)
                        .help("Automatically run cleanup every day at the specified time")

                    HStack {
                        Text("Cleanup Time")
                        Spacer()
                        TimePicker(time: $settings.dailyCleanupTime)
                            .disabled(!settings.dailyCleanupEnabled)
                    }

                    Divider()

                    Toggle("Enable weekly security scan", isOn: $settings.weeklySecurityScanEnabled)
                        .help("Automatically scan FileVault and Gatekeeper status weekly")

                    HStack {
                        Text("Scan Day")
                        Spacer()
                        Picker("", selection: $settings.weeklySecurityScanDay) {
                            Text("Sunday").tag(1)
                            Text("Monday").tag(2)
                            Text("Tuesday").tag(3)
                            Text("Wednesday").tag(4)
                            Text("Thursday").tag(5)
                            Text("Friday").tag(6)
                            Text("Saturday").tag(7)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                        .disabled(!settings.weeklySecurityScanEnabled)
                    }
                }
                .padding(8)
            }

            // Smart Triggers
            GroupBox("Smart Triggers") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Toggle("Battery trigger", isOn: $settings.batteryTriggerEnabled)
                            .help("Run gentle cleanup when battery drops below threshold")
                        Spacer()
                        Text(String(format: "< %.0f%%", settings.batteryThreshold))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.batteryThreshold, in: 10...50, step: 5)
                        .disabled(!settings.batteryTriggerEnabled)

                    HStack {
                        Toggle("Memory trigger", isOn: $settings.memoryTriggerEnabled)
                            .help("Run cleanup when memory usage exceeds threshold")
                        Spacer()
                        Text(String(format: "> %.0f%%", settings.memoryThreshold))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $settings.memoryThreshold, in: 50...95, step: 5)
                        .disabled(!settings.memoryTriggerEnabled)

                    Toggle("Thermal trigger", isOn: $settings.thermalTriggerEnabled)
                        .help("Run aggressive cleanup when Mac overheats (serious/critical thermal state)")
                        .padding(.top, 4)

                    Text("Triggers have a 5-minute cooldown to prevent repeated executions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }

            // Quiet Hours
            GroupBox("Quiet Hours") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable quiet hours", isOn: $settings.quietHoursEnabled)
                        .help("Suppress non-critical notifications during specified hours")

                    HStack {
                        Text("From")
                        TimePicker(time: $settings.quietHoursStart)
                            .disabled(!settings.quietHoursEnabled)
                        Text("To")
                        TimePicker(time: $settings.quietHoursEnd)
                            .disabled(!settings.quietHoursEnabled)
                    }

                    Toggle("Allow critical alerts during quiet hours", isOn: $settings.allowCriticalAlerts)
                        .help("Critical alerts (thermal, memory > 95%%) will still fire")
                        .padding(.top, 4)
                }
                .padding(8)
            }

            // Auto-cleanup Mode
            GroupBox("Auto-cleanup") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Skip confirmation for small cleanups", isOn: $settings.autoCleanupEnabled)
                        .help("Automatically execute cleanup without confirmation when under threshold")

                    HStack {
                        Text("Threshold")
                        Spacer()
                        Stepper(String(format: "%.0f MB", settings.autoCleanupThresholdMB),
                                value: $settings.autoCleanupThresholdMB, in: 100...2000, step: 100)
                            .frame(width: 150)
                            .disabled(!settings.autoCleanupEnabled)
                    }

                    Text("Large cleanups will still require confirmation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(8)
            }
        }
    }
}

// Simple time picker for HH:MM selection
struct TimePicker: View {
    @Binding var time: String

    var hour: Int {
        Int(time.split(separator: ":").first ?? "0") ?? 0
    }

    var minute: Int {
        Int(time.split(separator: ":").last ?? "0") ?? 0
    }

    var body: some View {
        HStack(spacing: 4) {
            Picker("", selection: Binding(
                get: { hour },
                set: { newValue in
                    time = String(format: "%02d:%02d", newValue, minute)
                }
            )) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(String(format: "%02d", hour)).tag(hour)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)

            Text(":")
                .monospacedDigit()

            Picker("", selection: Binding(
                get: { minute },
                set: { newValue in
                    time = String(format: "%02d:%02d", hour, newValue)
                }
            )) {
                ForEach(Array(stride(from: 0, to: 60, by: 5)), id: \.self) { minute in
                    Text(String(format: "%02d", minute)).tag(minute)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 70)
        }
    }
}

// MARK: - Alert Settings

struct AlertSettingsContent: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Alerts").font(.title2.bold())

            GroupBox("Notifications") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable Memory Alerts", isOn: $settings.notificationsEnabled)

                    HStack {
                        Text("Alert Cooldown")
                        Spacer()
                        Stepper("\(settings.alertCooldownMinutes) min",
                                value: $settings.alertCooldownMinutes, in: 1...60)
                    }
                }
                .padding(8)
            }

            GroupBox("Alert Thresholds") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(settings.alertThresholds) { threshold in
                        HStack {
                            Circle()
                                .fill(thresholdColor(threshold.percentage))
                                .frame(width: 10, height: 10)
                            Text(threshold.label)
                                .frame(width: 80, alignment: .leading)
                                .help("Alert when memory usage reaches this level")
                            Text("\(String(format: "%.0f", threshold.percentage))%")
                                .font(.system(.caption, design: .monospaced))
                                .help("Memory usage percentage threshold")
                            Spacer()
                            Toggle("", isOn: binding(for: threshold))
                                .toggleStyle(.switch)
                                .labelsHidden()
                        }
                        .help("Enable/disable \(threshold.label) alerts at \(String(format: "%.0f", threshold.percentage))% memory usage")
                    }
                }
                .padding(8)
            }
        }
    }

    private func thresholdColor(_ pct: Double) -> Color {
        if pct >= 95 { return .red }
        if pct >= 85 { return .orange }
        return .yellow
    }

    private func binding(for threshold: AlertThreshold) -> Binding<Bool> {
        Binding<Bool>(
            get: { threshold.isEnabled },
            set: { newValue in
                if let index = settings.alertThresholds.firstIndex(where: { $0.id == threshold.id }) {
                    let updated = settings.alertThresholds[index]
                    let newThreshold = AlertThreshold(
                        percentage: updated.percentage,
                        label: updated.label,
                        isEnabled: newValue,
                        soundEnabled: updated.soundEnabled,
                        notificationEnabled: updated.notificationEnabled
                    )
                    settings.alertThresholds[index] = newThreshold
                }
            }
        )
    }
}

// MARK: - Display Settings

struct DisplaySettingsContent: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display").font(.title2.bold())

            GroupBox("Feature Toggles") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show CPU Monitoring", isOn: $settings.showCPU)
                        .help("Toggle whether CPU monitoring is displayed in dashboard")
                    Toggle("Show Disk Monitoring", isOn: $settings.showDisk)
                        .help("Toggle whether disk usage monitoring is displayed in dashboard")
                    Toggle("Show Network Monitoring", isOn: $settings.showNetwork)
                        .help("Toggle whether network activity is displayed in dashboard")
                    Toggle("Show Battery/Thermal Monitoring", isOn: $settings.showBattery)
                        .help("Toggle whether battery and temperature monitoring is displayed in dashboard")
                }
                .padding(8)
            }

            GroupBox("History") {
                VStack(alignment: .leading, spacing: 8) {
                    Stepper("History Duration: \(settings.historyDurationMinutes) min",
                            value: $settings.historyDurationMinutes, in: 5...120, step: 5)
                        .help("How long historical data is retained (shorter = less memory usage)")
                }
                .padding(8)
            }

            GroupBox("About") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("App")
                        Spacer()
                        Text(Brand.name)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Built with")
                        Spacer()
                        Text("SwiftUI + Swift")
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Guard Settings

struct GuardSettingsContent: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var autoKill = AutoKillManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Process Guard").font(.title2.bold())

            GroupBox("Auto-Kill Runaway Processes") {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Enable Auto-Kill", isOn: $settings.autoKillEnabled)
                        .help("Automatically terminate processes using excessive memory or CPU")

                    HStack {
                        Text("Memory Threshold")
                        Spacer()
                        Text(String(format: "%.1f GB", settings.autoKillMemoryGB))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 60)
                    }
                    Slider(value: $settings.autoKillMemoryGB, in: 1...20, step: 0.5)
                        .help("Auto-kill processes using more than this amount of memory")

                    HStack {
                        Text("CPU Threshold")
                        Spacer()
                        Text(String(format: "%.0f%%", settings.autoKillCPUPercent))
                            .font(.system(.caption, design: .monospaced))
                            .frame(width: 60)
                    }
                    Slider(value: $settings.autoKillCPUPercent, in: 50...100, step: 5)
                        .help("Auto-kill processes using more than this percentage of CPU for extended periods")

                    Toggle("Show warning before killing", isOn: $settings.autoKillWarningFirst)
                        .help("Prompt for confirmation before terminating processes automatically")
                }
                .padding(8)
            }

            GroupBox("Whitelisted Processes") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("These processes will never be auto-killed:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    FlowLayout(spacing: 4) {
                        ForEach(autoKill.whitelistedProcesses, id: \.self) { name in
                            HStack(spacing: 2) {
                                Text(name)
                                    .font(.caption2)
                                Button { autoKill.removeFromWhitelist(name) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.secondary.opacity(0.7))
                                        .frame(width: 16, height: 16)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
                .padding(8)
            }
        }
        .onChange(of: settings.autoKillEnabled) { _, newVal in
            autoKill.isEnabled = newVal
        }
        .onChange(of: settings.autoKillMemoryGB) { _, newVal in
            autoKill.autoKillMemoryThresholdGB = newVal
        }
        .onChange(of: settings.autoKillCPUPercent) { _, newVal in
            autoKill.autoKillCPUThresholdPercent = newVal
        }
        .onChange(of: settings.autoKillWarningFirst) { _, newVal in
            autoKill.warningBeforeKill = newVal
        }
    }
}

// MARK: - Stats Settings

struct StatsSettingsContent: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedStatsTab: StatsTab = .triggerHistory

    enum StatsTab: String, CaseIterable {
        case triggerHistory = "Trigger History"
        case largeFiles = "Large Files"
        case privacyAudit = "Privacy Audit"
        case cleanupStats = "Cleanup Stats"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tab picker
            Picker("View", selection: $selectedStatsTab) {
                ForEach(StatsTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            // Content based on selection
            switch selectedStatsTab {
            case .triggerHistory:
                TriggerHistoryView()
                    .frame(minHeight: 300)
            case .largeFiles:
                LargeFileFinderView()
                    .frame(minHeight: 400)
            case .privacyAudit:
                PrivacyAuditView()
                    .frame(minHeight: 400)
            case .cleanupStats:
                CleanupStatsView()
            }
        }
    }
}

#Preview {
    SettingsView()
}
