import Foundation
import Combine
import AppKit

/// Central coordinator that ties all monitoring services together
class MemoryMonitorManager: ObservableObject {
    static let shared = MemoryMonitorManager()

    let systemMonitor = SystemMemoryMonitor.shared
    let processMonitor = ProcessMemoryMonitor.shared
    let cpuMonitor = CPUMonitor.shared
    let diskMonitor = DiskMonitor.shared
    let healthMonitor = SystemHealthMonitor.shared
    let alertManager = AlertManager.shared
    let autoKillManager = AutoKillManager.shared
    let settings = AppSettings.shared

    private var cancellables = Set<AnyCancellable>()
    private var processRefreshTimer: Timer?
    private var healthTimer: Timer?
    private var cpuTimer: Timer?

    @Published var isRunning = false

    private init() {
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        settings.$refreshInterval
            .removeDuplicates()
            .sink { [weak self] interval in
                if self?.isRunning == true {
                    self?.systemMonitor.startMonitoring(interval: interval)
                }
            }
            .store(in: &cancellables)

        settings.$autoKillEnabled
            .sink { [weak self] enabled in
                self?.autoKillManager.isEnabled = enabled
            }
            .store(in: &cancellables)
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Memory monitoring
        systemMonitor.startMonitoring(interval: settings.refreshInterval)

        // Process monitoring (every 5s)
        processRefreshTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.processMonitor.refresh(topN: self.settings.topProcessesCount)
            self.autoKillManager.checkProcesses()
        }
        processMonitor.refresh(topN: settings.topProcessesCount)

        // CPU monitoring (every 2s)
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.cpuMonitor.update()
        }
        cpuMonitor.update()

        // Health monitoring (every 3s)
        healthTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.healthMonitor.update()
        }
        healthMonitor.update()

        // Disk monitoring (every 10s, less frequent)
        diskMonitor.refresh()
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            self?.diskMonitor.refresh()
        }

        // Alert checks on memory updates
        systemMonitor.$currentMemory
            .compactMap { $0 }
            .sink { [weak self] memory in
                self?.alertManager.checkThresholds(memoryPercentage: memory.usedPercentage)
            }
            .store(in: &cancellables)

        autoKillManager.isEnabled = settings.autoKillEnabled
        autoKillManager.autoKillMemoryThresholdGB = settings.autoKillMemoryGB
        autoKillManager.autoKillCPUThresholdPercent = settings.autoKillCPUPercent
        autoKillManager.warningBeforeKill = settings.autoKillWarningFirst
    }

    func stop() {
        isRunning = false
        systemMonitor.stopMonitoring()
        processRefreshTimer?.invalidate()
        processRefreshTimer = nil
        healthTimer?.invalidate()
        healthTimer = nil
        cpuTimer?.invalidate()
        cpuTimer = nil
    }

    // MARK: - Quick Actions

    func killTopMemoryProcess() {
        guard let topProcess = processMonitor.topProcesses.first else { return }
        processMonitor.killProcess(pid: topProcess.id)
        processMonitor.refresh(topN: settings.topProcessesCount)
    }

    // MARK: - Overall Health Score

    var healthScore: Int {
        var score = 100

        // Memory penalty
        if let mem = systemMonitor.currentMemory {
            if mem.usedPercentage > 95 { score -= 40 }
            else if mem.usedPercentage > 85 { score -= 25 }
            else if mem.usedPercentage > 75 { score -= 10 }
            if mem.swapUsedGB > 1 { score -= 15 }
        }

        // CPU penalty
        let cpuTotal = cpuMonitor.userCPUPercentage + cpuMonitor.systemCPUPercentage
        if cpuTotal > 80 { score -= 20 }
        else if cpuTotal > 50 { score -= 10 }

        // Thermal penalty
        if healthMonitor.thermalState == "Critical" { score -= 25 }
        else if healthMonitor.thermalState == "Serious" { score -= 15 }

        // Disk penalty
        if let disk = diskMonitor.primaryDisk {
            if disk.usedPercentage > 95 { score -= 15 }
            else if disk.usedPercentage > 90 { score -= 10 }
        }

        return max(0, min(100, score))
    }

    var healthGrade: String {
        switch healthScore {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 50..<70: return "D"
        default: return "F"
        }
    }

    // MARK: - Formatted Menu Bar Text

    var menuBarText: String {
        switch settings.menuBarDisplayMode {
        case .memoryPercent:
            guard let memory = systemMonitor.currentMemory else { return "..." }
            return String(format: "%.0f%%", memory.usedPercentage)
        case .memoryGB:
            guard let memory = systemMonitor.currentMemory else { return "..." }
            return String(format: "%.1fG", memory.usedGB)
        case .cpuPercent:
            return String(format: "%.0f%%", cpuMonitor.userCPUPercentage + cpuMonitor.systemCPUPercentage)
        case .compact:
            guard let memory = systemMonitor.currentMemory else { return "..." }
            return String(format: "%.0f%%", memory.usedPercentage)
        }
    }

    var menuBarIcon: String {
        let pressure = systemMonitor.pressureLevel
        if pressure == .critical { return "exclamationmark.octagon.fill" }
        if pressure == .warning { return "exclamationmark.triangle.fill" }
        return "cpu.fill"
    }

    // MARK: - Recommendations

    var recommendations: [String] {
        var tips: [String] = []

        if let mem = systemMonitor.currentMemory {
            if mem.usedPercentage > 85 {
                tips.append("Memory is high. Close unused applications or browser tabs.")
            }
            if mem.swapUsedGB > 2 {
                tips.append("Heavy swap usage detected (\(String(format: "%.1f", mem.swapUsedGB))GB). This slows your Mac.")
            }
        }

        if cpuMonitor.systemCPUPercentage > 50 {
            tips.append("System CPU is elevated. Check for background processes.")
        }

        if let disk = diskMonitor.primaryDisk, disk.usedPercentage > 90 {
            tips.append("Disk is almost full (\(String(format: "%.0f", disk.usedPercentage))%). Free up space for better performance.")
        }

        if healthMonitor.thermalState == "Serious" || healthMonitor.thermalState == "Critical" {
            tips.append("Mac is overheating. Close demanding apps and check ventilation.")
        }

        if let topProcess = processMonitor.topProcesses.first, topProcess.memoryGB > 3 {
            tips.append("\"\(topProcess.name)\" is using \(String(format: "%.1f", topProcess.memoryGB))GB. Consider restarting it.")
        }

        if tips.isEmpty {
            tips.append("Your Mac is running well. Keep it up!")
        }

        return tips
    }
}


