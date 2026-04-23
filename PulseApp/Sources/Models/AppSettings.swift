import Foundation
import Combine
import ServiceManagement

/// Global application settings managed with Combine publisher pattern.
/// Persists settings with UserDefaults and synchronizes with UI state.
///
/// Thread safety: This class is NOT @MainActor. Settings are read from
/// background queues by monitoring services and written from the main thread
/// (Settings UI). @Published properties are mutated from the main thread;
/// reads from background threads are best-effort and may return stale values.
///
/// TODO: This coupling is the primary blocker for PulseCore extraction.
/// See PHASE_1A_REPORT.md for dependency inventory and proposed boundary.
class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultAlertThresholds: [AlertThreshold] = [
        AlertThreshold(percentage: 80, label: "Moderate", soundEnabled: false),
        AlertThreshold(percentage: 90, label: "High", soundEnabled: false),
        AlertThreshold(percentage: 95, label: "Critical", soundEnabled: false)
    ]

    // MARK: - Monitoring Settings
    /// How often to update system statistics in seconds (1s-10s range recommended)
    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    /// Whether to show Pulse icon and functionality in menubar
    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar") }
    }

    /// Whether to show percentage values in menubar alongside numerical values 
    @Published var showPercentageInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showPercentageInMenuBar, forKey: "showPercentageInMenuBar") }
    }

    /// Automatically start Pulse when computer turns on
    @Published var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin(launchAtLogin)
        }
    }

    // MARK: - Alert Thresholds
    @Published var alertThresholds: [AlertThreshold] {
        didSet { saveThresholds() }
    }

    // MARK: - Display Settings
    @Published var topProcessesCount: Int {
        didSet { UserDefaults.standard.set(topProcessesCount, forKey: "topProcessesCount") }
    }

    @Published var historyDurationMinutes: Int {
        didSet { UserDefaults.standard.set(historyDurationMinutes, forKey: "historyDurationMinutes") }
    }

    @Published var memoryUnit: MemoryUnit {
        didSet { UserDefaults.standard.set(memoryUnit.rawValue, forKey: "memoryUnit") }
    }

    // MARK: - Notification Settings
    @Published var notificationsEnabled: Bool {
        didSet { UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled") }
    }

    @Published var alertCooldownMinutes: Int {
        didSet { UserDefaults.standard.set(alertCooldownMinutes, forKey: "alertCooldownMinutes") }
    }

    // MARK: - Auto Kill Settings
    @Published var autoKillEnabled: Bool {
        didSet { UserDefaults.standard.set(autoKillEnabled, forKey: "autoKillEnabled") }
    }

    @Published var autoKillMemoryGB: Double {
        didSet { UserDefaults.standard.set(autoKillMemoryGB, forKey: "autoKillMemoryGB") }
    }

    @Published var autoKillCPUPercent: Double {
        didSet { UserDefaults.standard.set(autoKillCPUPercent, forKey: "autoKillCPUPercent") }
    }

    @Published var autoKillWarningFirst: Bool {
        didSet { UserDefaults.standard.set(autoKillWarningFirst, forKey: "autoKillWarningFirst") }
    }

    // MARK: - Feature Toggles
    /// Display CPU monitoring in main dashboard
    @Published var showCPU: Bool {
        didSet { UserDefaults.standard.set(showCPU, forKey: "showCPU") }
    }

    /// Display disk monitoring in main dashboard  
    @Published var showDisk: Bool {
        didSet { UserDefaults.standard.set(showDisk, forKey: "showDisk") }
    }

    /// Display network monitoring in main dashboard
    @Published var showNetwork: Bool {
        didSet { UserDefaults.standard.set(showNetwork, forKey: "showNetwork") }
    }

    /// Display battery and temperature monitoring in main dashboard
    @Published var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "showBattery") }
    }

    // MARK: - Menu Bar Display Mode
    /// How information is shown in menu bar icon and popover
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }

    // MARK: - Lite Mode (minimal menu bar, no heavy popover)
    /// When enabled, shows a minimal menu bar with just memory %, reducing CPU overhead
    @Published var liteMode: Bool {
        didSet { UserDefaults.standard.set(liteMode, forKey: "liteMode") }
    }

    // MARK: - Cleanup Settings
    /// Enable automated cleaning of Xcode derived data (compiled objects, indexing data)
    /// This is safe to enable, Xcode will regenerate as needed
    @Published var cleanXcodeDerivedData: Bool {
        didSet { UserDefaults.standard.set(cleanXcodeDerivedData, forKey: "cleanXcodeDerivedData") }
    }

    // MARK: - Disk Space Guardian Settings
    /// Enable Disk Space Guardian monitoring and alerts
    @Published var diskSpaceGuardianEnabled: Bool {
        didSet { UserDefaults.standard.set(diskSpaceGuardianEnabled, forKey: "diskSpaceGuardianEnabled") }
    }

    /// Warning threshold in GB (triggers alert when free space below this)
    @Published var diskWarningThresholdGB: Double {
        didSet { UserDefaults.standard.set(diskWarningThresholdGB, forKey: "diskWarningThresholdGB") }
    }

    /// Critical threshold in GB (triggers auto-cleanup when free space below this)
    @Published var diskCriticalThresholdGB: Double {
        didSet { UserDefaults.standard.set(diskCriticalThresholdGB, forKey: "diskCriticalThresholdGB") }
    }

    /// Enable automatic cleanup when disk space is critically low
    @Published var autoCleanupOnCriticalDisk: Bool {
        didSet { UserDefaults.standard.set(autoCleanupOnCriticalDisk, forKey: "autoCleanupOnCriticalDisk") }
    }

    @Published var autoCleanupThresholdGB: Double {
        didSet { UserDefaults.standard.set(autoCleanupThresholdGB, forKey: "autoCleanupThresholdGB") }
    }
    
    /// Clean old Xcode iOS device support files for versions no longer in active development
    /// Helps keep your development environment lean
    @Published var cleanXcodeDeviceSupport: Bool {
        didSet { UserDefaults.standard.set(cleanXcodeDeviceSupport, forKey: "cleanXcodeDeviceSupport") }
    }
    
    /// List of file paths that are protected from all cleaning operations
    /// Add any directories that contain important work you don't want accidentally deleted
    @Published var whitelistedPaths: [String] {
        didSet { UserDefaults.standard.set(whitelistedPaths, forKey: "whitelistedPaths") }
    }

    // MARK: - Auto Cleanup Settings
    @Published var autoCleanupEnabled: Bool {
        didSet { UserDefaults.standard.set(autoCleanupEnabled, forKey: "autoCleanupEnabled") }
    }

    @Published var autoCleanupIntervalHours: Int {
        didSet { UserDefaults.standard.set(autoCleanupIntervalHours, forKey: "autoCleanupIntervalHours") }
    }

    @Published var autoCleanupOnCriticalMemory: Bool {
        didSet { UserDefaults.standard.set(autoCleanupOnCriticalMemory, forKey: "autoCleanupOnCriticalMemory") }
    }

    // MARK: - Phase 2 Automation Settings

    // AutomationScheduler
    @Published var dailyCleanupEnabled: Bool {
        didSet { UserDefaults.standard.set(dailyCleanupEnabled, forKey: "automation.dailyCleanupEnabled") }
    }

    @Published var dailyCleanupTime: String {
        didSet { UserDefaults.standard.set(dailyCleanupTime, forKey: "automation.dailyCleanupTime") }
    }

    @Published var weeklySecurityScanEnabled: Bool {
        didSet { UserDefaults.standard.set(weeklySecurityScanEnabled, forKey: "automation.weeklySecurityScanEnabled") }
    }

    @Published var weeklySecurityScanDay: Int {
        didSet { UserDefaults.standard.set(weeklySecurityScanDay, forKey: "automation.weeklySecurityScanDay") }
    }

    // SmartTriggerMonitor
    @Published var batteryTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(batteryTriggerEnabled, forKey: "automation.batteryTriggerEnabled") }
    }

    @Published var batteryThreshold: Double {
        didSet { UserDefaults.standard.set(batteryThreshold, forKey: "automation.batteryThreshold") }
    }

    @Published var memoryTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(memoryTriggerEnabled, forKey: "automation.memoryTriggerEnabled") }
    }

    @Published var memoryThreshold: Double {
        didSet { UserDefaults.standard.set(memoryThreshold, forKey: "automation.memoryThreshold") }
    }

    @Published var thermalTriggerEnabled: Bool {
        didSet { UserDefaults.standard.set(thermalTriggerEnabled, forKey: "automation.thermalTriggerEnabled") }
    }

    // QuietHoursManager
    @Published var quietHoursEnabled: Bool {
        didSet { UserDefaults.standard.set(quietHoursEnabled, forKey: "automation.quietHoursEnabled") }
    }

    @Published var quietHoursStart: String {
        didSet { UserDefaults.standard.set(quietHoursStart, forKey: "automation.quietHoursStart") }
    }

    @Published var quietHoursEnd: String {
        didSet { UserDefaults.standard.set(quietHoursEnd, forKey: "automation.quietHoursEnd") }
    }

    @Published var allowCriticalAlerts: Bool {
        didSet { UserDefaults.standard.set(allowCriticalAlerts, forKey: "automation.allowCriticalAlerts") }
    }

    // Auto-cleanup Mode (confirmation bypass)
    @Published var autoCleanupThresholdMB: Double {
        didSet { UserDefaults.standard.set(autoCleanupThresholdMB, forKey: "automation.autoCleanupThresholdMB") }
    }

    // MARK: - Cleanup History
    @Published var totalFreedMB: Double {
        didSet { UserDefaults.standard.set(totalFreedMB, forKey: "totalFreedMB") }
    }

    @Published var totalCleanupCount: Int {
        didSet { UserDefaults.standard.set(totalCleanupCount, forKey: "totalCleanupCount") }
    }

    @Published var lastCleanupDate: Date? {
        didSet {
            if let date = lastCleanupDate {
                UserDefaults.standard.set(date, forKey: "lastCleanupDate")
            } else {
                UserDefaults.standard.removeObject(forKey: "lastCleanupDate")
            }
        }
    }

    // MARK: - Onboarding State
    /// Whether user has seen the permission onboarding flow
    @Published var hasSeenPermissionOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasSeenPermissionOnboarding, forKey: "hasSeenPermissionOnboarding") }
    }

    enum MemoryUnit: String, CaseIterable {
        case gb = "GB"
        case mb = "MB"
    }

    enum MenuBarDisplayMode: String, CaseIterable {
        case memoryPercent = "Memory %"
        case memoryGB = "Memory GB"
        case cpuPercent = "CPU %"
        case compact = "Both"
    }

    /// Initialize by reading from persistent user settings or using defaults
    private init() {
        // Load core monitoring settings
        self.refreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 2.0
        self.showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        self.showPercentageInMenuBar = UserDefaults.standard.object(forKey: "showPercentageInMenuBar") as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
        self.topProcessesCount = UserDefaults.standard.object(forKey: "topProcessesCount") as? Int ?? 10
        self.historyDurationMinutes = UserDefaults.standard.object(forKey: "historyDurationMinutes") as? Int ?? 60
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.alertCooldownMinutes = UserDefaults.standard.object(forKey: "alertCooldownMinutes") as? Int ?? 10

        // Load auto-kill settings
        self.autoKillEnabled = UserDefaults.standard.object(forKey: "autoKillEnabled") as? Bool ?? false
        self.autoKillMemoryGB = UserDefaults.standard.object(forKey: "autoKillMemoryGB") as? Double ?? 5.0
        self.autoKillCPUPercent = UserDefaults.standard.object(forKey: "autoKillCPUPercent") as? Double ?? 90.0
        self.autoKillWarningFirst = UserDefaults.standard.object(forKey: "autoKillWarningFirst") as? Bool ?? true

        // Load feature toggle settings
        self.showCPU = UserDefaults.standard.object(forKey: "showCPU") as? Bool ?? true
        self.showDisk = UserDefaults.standard.object(forKey: "showDisk") as? Bool ?? true
        self.showNetwork = UserDefaults.standard.object(forKey: "showNetwork") as? Bool ?? true
        self.showBattery = UserDefaults.standard.object(forKey: "showBattery") as? Bool ?? true

        // Load and validate memory units
        let unitRaw = UserDefaults.standard.string(forKey: "memoryUnit") ?? MemoryUnit.gb.rawValue
        self.memoryUnit = MemoryUnit(rawValue: unitRaw) ?? .gb

        // Load and validate menu bar display mode 
        let menuBarRaw = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.compact.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: menuBarRaw) ?? .compact
        self.liteMode = UserDefaults.standard.object(forKey: "liteMode") as? Bool ?? false

        // Load cleanup settings
        self.cleanXcodeDerivedData = UserDefaults.standard.object(forKey: "cleanXcodeDerivedData") as? Bool ?? false
        self.cleanXcodeDeviceSupport = UserDefaults.standard.object(forKey: "cleanXcodeDeviceSupport") as? Bool ?? false
        self.whitelistedPaths = UserDefaults.standard.stringArray(forKey: "whitelistedPaths") ?? []

        // Load Disk Space Guardian settings
        self.diskSpaceGuardianEnabled = UserDefaults.standard.object(forKey: "diskSpaceGuardianEnabled") as? Bool ?? true
        self.diskWarningThresholdGB = UserDefaults.standard.object(forKey: "diskWarningThresholdGB") as? Double ?? 20.0
        self.diskCriticalThresholdGB = UserDefaults.standard.object(forKey: "diskCriticalThresholdGB") as? Double ?? 10.0
        self.autoCleanupOnCriticalDisk = UserDefaults.standard.object(forKey: "autoCleanupOnCriticalDisk") as? Bool ?? true
        self.autoCleanupThresholdGB = UserDefaults.standard.object(forKey: "autoCleanupThresholdGB") as? Double ?? 5.0

        // Load auto-cleanup settings
        self.autoCleanupEnabled = UserDefaults.standard.object(forKey: "autoCleanupEnabled") as? Bool ?? false
        self.autoCleanupIntervalHours = UserDefaults.standard.object(forKey: "autoCleanupIntervalHours") as? Int ?? 24
        self.autoCleanupOnCriticalMemory = UserDefaults.standard.object(forKey: "autoCleanupOnCriticalMemory") as? Bool ?? true

        // Load Phase 2 automation settings
        self.dailyCleanupEnabled = UserDefaults.standard.object(forKey: "automation.dailyCleanupEnabled") as? Bool ?? false
        self.dailyCleanupTime = UserDefaults.standard.string(forKey: "automation.dailyCleanupTime") ?? "03:00"
        self.weeklySecurityScanEnabled = UserDefaults.standard.object(forKey: "automation.weeklySecurityScanEnabled") as? Bool ?? false
        self.weeklySecurityScanDay = UserDefaults.standard.object(forKey: "automation.weeklySecurityScanDay") as? Int ?? 1 // Sunday

        self.batteryTriggerEnabled = UserDefaults.standard.object(forKey: "automation.batteryTriggerEnabled") as? Bool ?? true
        self.batteryThreshold = UserDefaults.standard.object(forKey: "automation.batteryThreshold") as? Double ?? 30.0
        self.memoryTriggerEnabled = UserDefaults.standard.object(forKey: "automation.memoryTriggerEnabled") as? Bool ?? true
        self.memoryThreshold = UserDefaults.standard.object(forKey: "automation.memoryThreshold") as? Double ?? 80.0
        self.thermalTriggerEnabled = UserDefaults.standard.object(forKey: "automation.thermalTriggerEnabled") as? Bool ?? true

        self.quietHoursEnabled = UserDefaults.standard.object(forKey: "automation.quietHoursEnabled") as? Bool ?? false
        self.quietHoursStart = UserDefaults.standard.string(forKey: "automation.quietHoursStart") ?? "22:00"
        self.quietHoursEnd = UserDefaults.standard.string(forKey: "automation.quietHoursEnd") ?? "08:00"
        self.allowCriticalAlerts = UserDefaults.standard.object(forKey: "automation.allowCriticalAlerts") as? Bool ?? true

        self.autoCleanupThresholdMB = UserDefaults.standard.object(forKey: "automation.autoCleanupThresholdMB") as? Double ?? 500.0

        // Load cleanup history
        self.totalFreedMB = UserDefaults.standard.object(forKey: "totalFreedMB") as? Double ?? 0
        self.totalCleanupCount = UserDefaults.standard.object(forKey: "totalCleanupCount") as? Int ?? 0
        self.lastCleanupDate = UserDefaults.standard.object(forKey: "lastCleanupDate") as? Date

        // Load onboarding state
        self.hasSeenPermissionOnboarding = UserDefaults.standard.object(forKey: "hasSeenPermissionOnboarding") as? Bool ?? false

        // Load and validate alert thresholds
        if let data = UserDefaults.standard.data(forKey: "alertThresholds"),
           let decoded = try? JSONDecoder().decode([AlertThreshold].self, from: data) {
            self.alertThresholds = Self.sanitizedThresholds(decoded)
        } else {
            self.alertThresholds = Self.defaultAlertThresholds
        }
        
        // Ensure launch at login status is synchronized with the actual system status
        syncLaunchAtLoginStatus()
    }

    /// Sanitizes alert thresholds to prevent corrupt configuration data from persisting
    /// - Parameter thresholds: Previously configured thresholds
    /// - Returns: Valid AlertThreshold array matching current schema requirements 
    private static func sanitizedThresholds(_ thresholds: [AlertThreshold]) -> [AlertThreshold] {
        let validPercentages = [80.0, 90.0, 95.0]
        let hasLegacyThresholds = thresholds.contains { !validPercentages.contains($0.percentage) }
        guard !hasLegacyThresholds, thresholds.count == 3 else {
            // User's saved settings don't match current schema - return defaults
            // This handles cases like upgrades between versions with different thresholds
            return defaultAlertThresholds
        }

        // Update properties that may have changed schema structure while preserving percentages
        return thresholds.map { threshold in
            var normalized = threshold
            // Reset new properties to reasonable defaults during migration
            normalized.soundEnabled = false
            normalized.notificationEnabled = true
            return normalized
        }.sorted { $0.percentage < $1.percentage }
    }

    private func saveThresholds() {
        if let encoded = try? JSONEncoder().encode(alertThresholds) {
            UserDefaults.standard.set(encoded, forKey: "alertThresholds")
        }
    }
    
    // MARK: - Launch at Login
    
    private func applyLaunchAtLogin(_ enable: Bool) {
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("[AppSettings] Launch at login failed: \(error)")
        }
    }
    
    private func syncLaunchAtLoginStatus() {
        let actualStatus = SMAppService.mainApp.status == .enabled
        if launchAtLogin != actualStatus {
            launchAtLogin = actualStatus
        }
    }

    // MARK: - Test Helpers

    /// Reset all automation-related settings to default values
    /// Call this in test tearDown to ensure test isolation
    func resetAutomationSettingsToDefaults() {
        // AutomationScheduler settings
        dailyCleanupEnabled = false
        dailyCleanupTime = "03:00"
        weeklySecurityScanEnabled = false
        weeklySecurityScanDay = 1 // Sunday

        // SmartTriggerMonitor settings
        batteryTriggerEnabled = true
        batteryThreshold = 30.0
        memoryTriggerEnabled = true
        memoryThreshold = 80.0
        thermalTriggerEnabled = true

        // QuietHoursManager settings
        quietHoursEnabled = false
        quietHoursStart = "22:00"
        quietHoursEnd = "08:00"
        allowCriticalAlerts = true

        // Auto-cleanup threshold
        autoCleanupThresholdMB = 500.0
    }
}
