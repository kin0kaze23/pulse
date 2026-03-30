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
    let optimizer = MemoryOptimizer.shared
    let settings = AppSettings.shared
    let devMonitor = DeveloperMonitor.shared
    let devProfilesEngine = DeveloperProfilesEngine.shared

    private var cancellables = Set<AnyCancellable>()
    private var processRefreshTimer: Timer?
    private var healthTimer: Timer?
    private var cpuTimer: Timer?
    private var cycleCountTimer: Timer?

    @Published var isRunning = false
    @Published var liteMode = false

    private init() {
        liteMode = settings.liteMode
        setupBindings()
    }

    // MARK: - Setup

    private func setupBindings() {
        let childPublishers: [AnyPublisher<Void, Never>] = [
            systemMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            processMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            cpuMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            diskMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            healthMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            alertManager.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            autoKillManager.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            optimizer.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            settings.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            devMonitor.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
            devProfilesEngine.objectWillChange.map { _ in () }.eraseToAnyPublisher(),
        ]

        Publishers.MergeMany(childPublishers)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

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

        settings.$liteMode
            .sink { [weak self] enabled in
                self?.liteMode = enabled
            }
            .store(in: &cancellables)

        processMonitor.$topProcesses
            .sink { [weak self] processes in
                guard let self, let candidate = processes.first(where: { $0.isSafeToClose && $0.memoryGB > 1.5 }) else { return }
                self.alertManager.maybeRecommendClosing(process: candidate)
            }
            .store(in: &cancellables)
    }

    // MARK: - Start / Stop

    func start() {
        guard !isRunning else { return }
        isRunning = true

        // Start historical metrics recording for trend analysis
        HistoricalMetricsService.shared.startRecording()

        // Memory monitoring (default 3s, was 2s)
        let memInterval = max(settings.refreshInterval, 3.0)
        systemMonitor.startMonitoring(interval: memInterval)

        // Process monitoring (every 10s, was 5s)
        processRefreshTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.processMonitor.refresh(topN: self.settings.topProcessesCount)
            self.autoKillManager.checkProcesses()
        }
        processMonitor.refresh(topN: settings.topProcessesCount)

        // CPU monitoring (every 5s for better performance)
        cpuTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.cpuMonitor.update()
        }
        cpuMonitor.update()

        // Health monitoring (every 5s, was 3s) — battery now runs on background thread
        healthTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.healthMonitor.update()
        }
        healthMonitor.update()

        // Cycle count (every 30s — expensive ioreg call, not urgent)
        cycleCountTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.healthMonitor.updateCycleCount()
        }
        healthMonitor.updateCycleCount()

        // Disk monitoring (every 30s, was 10s — rarely changes)
        diskMonitor.refresh()
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.diskMonitor.refresh()
        }

        // Alert checks and health score recalculation on metric changes
        // Memory changes
        systemMonitor.$currentMemory
            .compactMap { $0 }
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] memory in
                self?.alertManager.checkThresholds(memoryPercentage: memory.usedPercentage)
                self?.healthScoreService.calculateScore()
            }
            .store(in: &cancellables)

        // CPU changes
        cpuMonitor.$userCPUPercentage
            .debounce(for: .seconds(2), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.healthScoreService.calculateScore()
            }
            .store(in: &cancellables)

        // Thermal changes
        healthMonitor.$thermalState
            .removeDuplicates()
            .sink { [weak self] _ in
                self?.healthScoreService.calculateScore()
            }
            .store(in: &cancellables)

        // Disk changes
        diskMonitor.$primaryDisk
            .sink { [weak self] _ in
                self?.healthScoreService.calculateScore()
            }
            .store(in: &cancellables)

        autoKillManager.isEnabled = settings.autoKillEnabled
        autoKillManager.autoKillMemoryThresholdGB = settings.autoKillMemoryGB
        autoKillManager.autoKillCPUThresholdPercent = settings.autoKillCPUPercent
        autoKillManager.warningBeforeKill = settings.autoKillWarningFirst

        // Initial health score calculation
        healthScoreService.calculateScore()
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
        cycleCountTimer?.invalidate()
        cycleCountTimer = nil
    }

    // MARK: - Quick Actions

    func killTopMemoryProcess() {
        guard let topProcess = processMonitor.topProcesses.first else { return }
        processMonitor.killProcess(pid: topProcess.id)
        processMonitor.refresh(topN: settings.topProcessesCount)
    }

    func freeRAM() {
        optimizer.freeRAM()
    }

    // MARK: - Health Score with Breakdown
    // Note: Now uses HealthScoreService for trend-based calculation

    /// Legacy health score - kept for backward compatibility
    /// Use healthScoreService.currentResult for trend-based score
    var healthScore: Int {
        healthScoreService.currentResult?.currentScore ?? calculateLegacyScore()
    }
    
    /// Legacy health grade - kept for backward compatibility
    var healthGrade: String {
        healthScoreService.currentResult?.currentGrade.rawValue ?? gradeForLegacyScore(healthScore)
    }
    
    /// New health score service with trends
    let healthScoreService = HealthScoreService.shared
    
    /// Calculate legacy score (snapshot only, no trends)
    private func calculateLegacyScore() -> Int {
        let totalPenalty = healthBreakdown.reduce(0) { $0 + $1.pointsLost }
        return max(0, 100 - totalPenalty)
    }
    
    /// Get grade for legacy score
    private func gradeForLegacyScore(_ score: Int) -> String {
        switch score {
        case 90...100: return "A"
        case 80..<90: return "B"
        case 70..<80: return "C"
        case 50..<70: return "D"
        default: return "F"
        }
    }

    /// Legacy health breakdown - kept for backward compatibility
    var healthBreakdown: [MemoryMonitorManager.HealthPenalty] {
        var penalties: [HealthPenalty] = []

        // Memory penalty
        if let mem = systemMonitor.currentMemory {
            if mem.usedPercentage > 95 {
                penalties.append(HealthPenalty(category: "Memory", pointsLost: 40, reason: String(format: "%.0f%% used — critical", mem.usedPercentage)))
            } else if mem.usedPercentage > 85 {
                penalties.append(HealthPenalty(category: "Memory", pointsLost: 25, reason: String(format: "%.0f%% used — high", mem.usedPercentage)))
            } else if mem.usedPercentage > 75 {
                penalties.append(HealthPenalty(category: "Memory", pointsLost: 10, reason: String(format: "%.0f%% used", mem.usedPercentage)))
            }

            if mem.swapUsedGB > 5 {
                penalties.append(HealthPenalty(category: "Swap", pointsLost: 20, reason: String(format: "%.1f GB swap — critical", mem.swapUsedGB)))
            } else if mem.swapUsedGB > 2 {
                penalties.append(HealthPenalty(category: "Swap", pointsLost: 15, reason: String(format: "%.1f GB swap — heavy", mem.swapUsedGB)))
            } else if mem.swapUsedGB > 1 {
                penalties.append(HealthPenalty(category: "Swap", pointsLost: 8, reason: String(format: "%.1f GB swap used", mem.swapUsedGB)))
            }
        }

        // CPU penalty
        let cpuTotal = cpuMonitor.userCPUPercentage + cpuMonitor.systemCPUPercentage
        if cpuTotal > 80 {
            penalties.append(HealthPenalty(category: "CPU", pointsLost: 20, reason: String(format: "%.0f%% — overloaded", cpuTotal)))
        } else if cpuTotal > 50 {
            penalties.append(HealthPenalty(category: "CPU", pointsLost: 10, reason: String(format: "%.0f%% — elevated", cpuTotal)))
        }

        // Thermal penalty
        if healthMonitor.thermalState == "Critical" {
            penalties.append(HealthPenalty(category: "Thermal", pointsLost: 25, reason: "Critical — throttling"))
        } else if healthMonitor.thermalState == "Serious" {
            penalties.append(HealthPenalty(category: "Thermal", pointsLost: 15, reason: "Serious — hot"))
        }

        // Disk penalty
        if let disk = diskMonitor.primaryDisk {
            if disk.usedPercentage > 95 {
                penalties.append(HealthPenalty(category: "Disk", pointsLost: 15, reason: String(format: "%.0f%% full — critical", disk.usedPercentage)))
            } else if disk.usedPercentage > 90 {
                penalties.append(HealthPenalty(category: "Disk", pointsLost: 10, reason: String(format: "%.0f%% full", disk.usedPercentage)))
            }
        }

        return penalties
    }
    
    struct HealthPenalty {
        let category: String
        let pointsLost: Int
        let reason: String
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

    // MARK: - Actionable Recommendations

    struct Recommendation: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let action: RecommendationAction
        let severity: Severity

        enum RecommendationAction {
            case freeRAM
            case cleanCaches(cacheMB: Double)
            case closeApp(name: String, pid: Int32, memoryGB: Double)
            case freeDiskSpace
            case coolDown
            case none
        }

        enum Severity {
            case info, warning, critical

            var color: String {
                switch self {
                case .info: return "green"
                case .warning: return "orange"
                case .critical: return "red"
                }
            }
        }
    }

    var actionableRecommendations: [Recommendation] {
        var tips: [Recommendation] = []

        if let mem = systemMonitor.currentMemory {
            // High memory → suggest free RAM
            if mem.usedPercentage > 85 {
                tips.append(Recommendation(
                    icon: "memorychip.fill",
                    title: "Memory is high (\(String(format: "%.0f", mem.usedPercentage))%)",
                    detail: "Free cached memory to improve performance",
                    action: .freeRAM,
                    severity: mem.usedPercentage > 95 ? .critical : .warning
                ))
            }

            // Heavy swap → suggest free RAM + close apps
            if mem.swapUsedGB > 2 {
                tips.append(Recommendation(
                    icon: "arrow.triangle.2.circlepath",
                    title: "Heavy swap (\(String(format: "%.1f", mem.swapUsedGB)) GB)",
                    detail: "Swap slows your Mac. Free RAM or close apps.",
                    action: .freeRAM,
                    severity: mem.swapUsedGB > 5 ? .critical : .warning
                ))
            }
        }

        // Cache cleanup suggestion
        let cacheMB = optimizer.scanCacheSize()
        if cacheMB > 500 {
            tips.append(Recommendation(
                icon: "trash.fill",
                title: "\(String(format: "%.0f", cacheMB)) MB of caches",
                detail: "Safe to clean — macOS rebuilds automatically",
                action: .cleanCaches(cacheMB: cacheMB),
                severity: cacheMB > 2000 ? .warning : .info
            ))
        }

        // Top memory hog suggestion
        if let topProcess = processMonitor.topProcesses.first, topProcess.memoryGB > 2 {
            tips.append(Recommendation(
                icon: "app.fill",
                title: "\"\(topProcess.name)\" using \(String(format: "%.1f", topProcess.memoryGB)) GB",
                detail: "Consider restarting if not actively using",
                action: .closeApp(name: topProcess.name, pid: topProcess.id, memoryGB: topProcess.memoryGB),
                severity: topProcess.memoryGB > 5 ? .warning : .info
            ))
        }

        // Disk full
        if let disk = diskMonitor.primaryDisk, disk.usedPercentage > 90 {
            tips.append(Recommendation(
                icon: "internaldrive.fill",
                title: "Disk \(String(format: "%.0f", disk.usedPercentage))% full",
                detail: "Low disk space forces more swap usage",
                action: .freeDiskSpace,
                severity: disk.usedPercentage > 95 ? .critical : .warning
            ))
        }

        // Thermal
        if healthMonitor.thermalState == "Serious" || healthMonitor.thermalState == "Critical" {
            tips.append(Recommendation(
                icon: "thermometer.high",
                title: "Mac is overheating (\(healthMonitor.thermalState))",
                detail: "Close demanding apps, check ventilation",
                action: .coolDown,
                severity: .critical
            ))
        }

        // All good
        if tips.isEmpty {
            tips.append(Recommendation(
                icon: "checkmark.circle.fill",
                title: "Your Mac is running well!",
                detail: "All systems nominal",
                action: .none,
                severity: .info
            ))
        }

        return tips
    }

    /// Legacy text-only recommendations (for menu bar popover compatibility)
    var recommendations: [String] {
        actionableRecommendations.map { $0.title + ". " + $0.detail }
    }
}
