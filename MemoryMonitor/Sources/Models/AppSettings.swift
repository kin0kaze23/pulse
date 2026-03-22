import Foundation
import Combine
import ServiceManagement

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    static let defaultAlertThresholds: [AlertThreshold] = [
        AlertThreshold(percentage: 80, label: "Moderate", soundEnabled: false),
        AlertThreshold(percentage: 90, label: "High", soundEnabled: false),
        AlertThreshold(percentage: 95, label: "Critical", soundEnabled: false)
    ]

    // MARK: - Monitoring Settings
    @Published var refreshInterval: Double {
        didSet { UserDefaults.standard.set(refreshInterval, forKey: "refreshInterval") }
    }

    @Published var showInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showInMenuBar, forKey: "showInMenuBar") }
    }

    @Published var showPercentageInMenuBar: Bool {
        didSet { UserDefaults.standard.set(showPercentageInMenuBar, forKey: "showPercentageInMenuBar") }
    }

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
    @Published var showCPU: Bool {
        didSet { UserDefaults.standard.set(showCPU, forKey: "showCPU") }
    }

    @Published var showDisk: Bool {
        didSet { UserDefaults.standard.set(showDisk, forKey: "showDisk") }
    }

    @Published var showNetwork: Bool {
        didSet { UserDefaults.standard.set(showNetwork, forKey: "showNetwork") }
    }

    @Published var showBattery: Bool {
        didSet { UserDefaults.standard.set(showBattery, forKey: "showBattery") }
    }

    // MARK: - Menu Bar Display Mode
    @Published var menuBarDisplayMode: MenuBarDisplayMode {
        didSet { UserDefaults.standard.set(menuBarDisplayMode.rawValue, forKey: "menuBarDisplayMode") }
    }

    // MARK: - Lite Mode (minimal menu bar, no heavy popover)
    @Published var liteMode: Bool {
        didSet { UserDefaults.standard.set(liteMode, forKey: "liteMode") }
    }

    // MARK: - Cleanup Settings
    @Published var cleanXcodeDerivedData: Bool {
        didSet { UserDefaults.standard.set(cleanXcodeDerivedData, forKey: "cleanXcodeDerivedData") }
    }

    @Published var cleanXcodeDeviceSupport: Bool {
        didSet { UserDefaults.standard.set(cleanXcodeDeviceSupport, forKey: "cleanXcodeDeviceSupport") }
    }

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

    private init() {
        self.refreshInterval = UserDefaults.standard.object(forKey: "refreshInterval") as? Double ?? 2.0
        self.showInMenuBar = UserDefaults.standard.object(forKey: "showInMenuBar") as? Bool ?? true
        self.showPercentageInMenuBar = UserDefaults.standard.object(forKey: "showPercentageInMenuBar") as? Bool ?? true
        self.launchAtLogin = UserDefaults.standard.object(forKey: "launchAtLogin") as? Bool ?? false
        self.topProcessesCount = UserDefaults.standard.object(forKey: "topProcessesCount") as? Int ?? 10
        self.historyDurationMinutes = UserDefaults.standard.object(forKey: "historyDurationMinutes") as? Int ?? 60
        self.notificationsEnabled = UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
        self.alertCooldownMinutes = UserDefaults.standard.object(forKey: "alertCooldownMinutes") as? Int ?? 10

        self.autoKillEnabled = UserDefaults.standard.object(forKey: "autoKillEnabled") as? Bool ?? false
        self.autoKillMemoryGB = UserDefaults.standard.object(forKey: "autoKillMemoryGB") as? Double ?? 5.0
        self.autoKillCPUPercent = UserDefaults.standard.object(forKey: "autoKillCPUPercent") as? Double ?? 90.0
        self.autoKillWarningFirst = UserDefaults.standard.object(forKey: "autoKillWarningFirst") as? Bool ?? true

        self.showCPU = UserDefaults.standard.object(forKey: "showCPU") as? Bool ?? true
        self.showDisk = UserDefaults.standard.object(forKey: "showDisk") as? Bool ?? true
        self.showNetwork = UserDefaults.standard.object(forKey: "showNetwork") as? Bool ?? true
        self.showBattery = UserDefaults.standard.object(forKey: "showBattery") as? Bool ?? true

        let unitRaw = UserDefaults.standard.string(forKey: "memoryUnit") ?? MemoryUnit.gb.rawValue
        self.memoryUnit = MemoryUnit(rawValue: unitRaw) ?? .gb

        let menuBarRaw = UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.compact.rawValue
        self.menuBarDisplayMode = MenuBarDisplayMode(rawValue: menuBarRaw) ?? .compact
        self.liteMode = UserDefaults.standard.object(forKey: "liteMode") as? Bool ?? false

        // Cleanup settings
        self.cleanXcodeDerivedData = UserDefaults.standard.object(forKey: "cleanXcodeDerivedData") as? Bool ?? false
        self.cleanXcodeDeviceSupport = UserDefaults.standard.object(forKey: "cleanXcodeDeviceSupport") as? Bool ?? false
        self.whitelistedPaths = UserDefaults.standard.stringArray(forKey: "whitelistedPaths") ?? []

        // Auto cleanup settings
        self.autoCleanupEnabled = UserDefaults.standard.object(forKey: "autoCleanupEnabled") as? Bool ?? false
        self.autoCleanupIntervalHours = UserDefaults.standard.object(forKey: "autoCleanupIntervalHours") as? Int ?? 24
        self.autoCleanupOnCriticalMemory = UserDefaults.standard.object(forKey: "autoCleanupOnCriticalMemory") as? Bool ?? true

        // Cleanup history
        self.totalFreedMB = UserDefaults.standard.object(forKey: "totalFreedMB") as? Double ?? 0
        self.totalCleanupCount = UserDefaults.standard.object(forKey: "totalCleanupCount") as? Int ?? 0
        self.lastCleanupDate = UserDefaults.standard.object(forKey: "lastCleanupDate") as? Date

        // Load thresholds or set defaults
        if let data = UserDefaults.standard.data(forKey: "alertThresholds"),
           let decoded = try? JSONDecoder().decode([AlertThreshold].self, from: data) {
            self.alertThresholds = Self.sanitizedThresholds(decoded)
        } else {
            self.alertThresholds = Self.defaultAlertThresholds
        }
        
        // Sync launch at login status with SMAppService
        syncLaunchAtLoginStatus()
    }

    private static func sanitizedThresholds(_ thresholds: [AlertThreshold]) -> [AlertThreshold] {
        let validPercentages = [80.0, 90.0, 95.0]
        let hasLegacyThresholds = thresholds.contains { !validPercentages.contains($0.percentage) }
        guard !hasLegacyThresholds, thresholds.count == 3 else {
            return defaultAlertThresholds
        }

        return thresholds.map { threshold in
            var normalized = threshold
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
}
