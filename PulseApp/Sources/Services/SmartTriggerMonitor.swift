import Foundation
import Combine
import AppKit

/// Monitors system triggers (battery, memory, thermal) and fires automated actions
class SmartTriggerMonitor: ObservableObject {
    static let shared = SmartTriggerMonitor()

    // MARK: - Published Properties (synced with AppSettings)

    @Published var batteryTriggerEnabled: Bool
    @Published var batteryThreshold: Double // percent (default 30%)
    @Published var memoryTriggerEnabled: Bool
    @Published var memoryThreshold: Double // percent (default 80%)
    @Published var thermalTriggerEnabled: Bool

    // MARK: - Internal State

    @Published var lastTriggerTime: [String: Date] = [:]
    private let triggerCooldown: TimeInterval = 300 // 5 minutes

    private let workQueue = DispatchQueue(label: "com.pulse.smarttrigger", qos: .utility)
    private let settings = AppSettings.shared
    private let healthMonitor = SystemHealthMonitor.shared
    private let systemMonitor = SystemMemoryMonitor.shared
    private let optimizer = ComprehensiveOptimizer.shared
    private let alertManager = AlertManager.shared
    private let metricsService = HistoricalMetricsService.shared

    // Prevent infinite loops in two-way sync
    private var isSyncingSettings = false

    private var cancellables = Set<AnyCancellable>()
    private var checkTimer: Timer?

    // MARK: - Initialization

    private init() {
        self.batteryTriggerEnabled = settings.batteryTriggerEnabled
        self.batteryThreshold = settings.batteryThreshold
        self.memoryTriggerEnabled = settings.memoryTriggerEnabled
        self.memoryThreshold = settings.memoryThreshold
        self.thermalTriggerEnabled = settings.thermalTriggerEnabled

        setupSettingsSync()
    }

    // MARK: - Settings Sync

    private func setupSettingsSync() {
        // Sync AppSettings -> Monitor
        settings.$batteryTriggerEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.batteryTriggerEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$batteryThreshold
            .sink { [weak self] threshold in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.batteryThreshold = threshold
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$memoryTriggerEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.memoryTriggerEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$memoryThreshold
            .sink { [weak self] threshold in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.memoryThreshold = threshold
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$thermalTriggerEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.thermalTriggerEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        // Sync Monitor -> AppSettings (two-way sync)
        $batteryTriggerEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.batteryTriggerEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $batteryThreshold
            .dropFirst()
            .sink { [weak self] threshold in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.batteryThreshold = threshold
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $memoryTriggerEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.memoryTriggerEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $memoryThreshold
            .dropFirst()
            .sink { [weak self] threshold in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.memoryThreshold = threshold
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $thermalTriggerEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.thermalTriggerEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Start monitoring triggers (called by MemoryMonitorManager)
    func startMonitoring() {
        // Check triggers every 30 seconds
        checkTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.checkTriggers()
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        checkTimer?.invalidate()
        checkTimer = nil
    }

    // MARK: - Trigger Detection

    /// Check all triggers and fire if conditions are met
    func checkTriggers() {
        checkBatteryTrigger()
        checkMemoryTrigger()
        checkThermalTrigger()
    }

    private func checkBatteryTrigger() {
        guard batteryTriggerEnabled else { return }
        guard !healthMonitor.isCharging else { return } // Only trigger on battery power

        let batteryPercent = healthMonitor.batteryPercentage
        if batteryPercent < batteryThreshold {
            fireTrigger(type: .batteryLow, threshold: batteryThreshold, value: batteryPercent) { [weak self] in
                self?.runGentleCleanup()
            }
        }
    }

    private func checkMemoryTrigger() {
        guard memoryTriggerEnabled else { return }

        // Get memory percentage from currentMemory
        guard let currentMemory = systemMonitor.currentMemory else { return }
        let memoryUsedPercent = currentMemory.usedPercentage

        if memoryUsedPercent > memoryThreshold {
            fireTrigger(type: .memoryHigh, threshold: memoryThreshold, value: memoryUsedPercent) { [weak self] in
                self?.runStandardCleanup()
            }
        }
    }

    private func checkThermalTrigger() {
        guard thermalTriggerEnabled else { return }

        if healthMonitor.thermalState == "Serious" || healthMonitor.thermalState == "Critical" {
            fireTrigger(type: .thermalCritical, threshold: nil, value: nil) { [weak self] in
                self?.runAggressiveCleanup()
            }
        }
    }

    // MARK: - Debounce Logic

    /// Fire trigger with debounce to prevent repeated triggers
    private func fireTrigger(type: TriggerType, threshold: Double?, value: Double?, action: @escaping () -> Void) {
        let now = Date()
        let key = type.rawValue
        let lastTime = lastTriggerTime[key, default: .distantPast]

        guard now.timeIntervalSince(lastTime) > triggerCooldown else {
            // Cooldown active - skip
            return
        }

        lastTriggerTime[key] = now

        // Log trigger start
        let triggerEvent = TriggerEvent(
            type: type,
            value: value,
            threshold: threshold,
            success: false, // Will be updated after action completes
            errorMessage: "Trigger fired, action pending"
        )
        metricsService.addTriggerEvent(triggerEvent)

        action()

        print("[SmartTriggerMonitor] Fired \(type.displayName) trigger (action executed)")
    }

    // MARK: - Cleanup Actions

    /// Battery trigger: gentle cleanup (caches only)
    private func runGentleCleanup() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            print("[SmartTriggerMonitor] Running gentle cleanup (battery trigger)...")

            DispatchQueue.main.async {
                self.optimizer.scanForCleanup()

                // Execute cleanup with auto-confirmation if under threshold
                if let plan = self.optimizer.currentPlan {
                    if self.settings.autoCleanupEnabled && plan.totalSizeMB < self.settings.autoCleanupThresholdMB {
                        self.optimizer.executeCleanup()
                        print("[SmartTriggerMonitor] Gentle cleanup executed")
                    }
                }
            }
        }
    }

    /// Memory trigger: standard cleanup
    private func runStandardCleanup() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            print("[SmartTriggerMonitor] Running standard cleanup (memory trigger)...")

            DispatchQueue.main.async {
                self.optimizer.scanForCleanup()

                if let plan = self.optimizer.currentPlan {
                    // Auto-execute if under threshold
                    if self.settings.autoCleanupEnabled && plan.totalSizeMB < self.settings.autoCleanupThresholdMB {
                        self.optimizer.executeCleanup()
                        print("[SmartTriggerMonitor] Standard cleanup executed")
                    }
                    // Otherwise skip - user will see regular alert from AlertManager
                }
            }
        }
    }

    /// Thermal trigger: aggressive cleanup + notify user
    private func runAggressiveCleanup() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            print("[SmartTriggerMonitor] Running aggressive cleanup (thermal trigger)...")

            DispatchQueue.main.async {
                self.optimizer.scanForCleanup()
                self.optimizer.executeCleanup()

                // Notify user about thermal situation
                self.alertManager.checkThresholds(memoryPercentage: 95)

                print("[SmartTriggerMonitor] Aggressive cleanup executed")
            }
        }
    }

    // MARK: - Trigger History (for future UI)

    /// Log trigger event for history tracking
    func logTriggerEvent(type: TriggerType, freedMB: Double, value: Double? = nil) {
        let event = TriggerEvent(
            type: type,
            value: value,
            freedMB: freedMB
        )
        metricsService.addTriggerEvent(event)
        print("[SmartTriggerMonitor] Logged trigger: \(type.displayName), freed \(freedMB)MB")
    }

    /// Log failed trigger event
    func logFailedTrigger(type: TriggerType, error: String, value: Double? = nil) {
        let event = TriggerEvent(
            type: type,
            value: value,
            success: false,
            errorMessage: error
        )
        metricsService.addTriggerEvent(event)
        print("[SmartTriggerMonitor] Logged failed trigger: \(type.displayName), error: \(error)")
    }
}
