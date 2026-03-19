import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

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
        didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
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
        self.alertCooldownMinutes = UserDefaults.standard.object(forKey: "alertCooldownMinutes") as? Int ?? 5

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

        // Load thresholds or set defaults
        if let data = UserDefaults.standard.data(forKey: "alertThresholds"),
           let decoded = try? JSONDecoder().decode([AlertThreshold].self, from: data) {
            self.alertThresholds = decoded
        } else {
            self.alertThresholds = [
                AlertThreshold(percentage: 75, label: "Moderate"),
                AlertThreshold(percentage: 85, label: "High"),
                AlertThreshold(percentage: 95, label: "Critical")
            ]
        }
    }

    private func saveThresholds() {
        if let encoded = try? JSONEncoder().encode(alertThresholds) {
            UserDefaults.standard.set(encoded, forKey: "alertThresholds")
        }
    }
}
