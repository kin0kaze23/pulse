import Foundation
import Combine
import AppKit

/// Schedules and manages automated cleanup and security scan jobs
class AutomationScheduler: ObservableObject {
    static let shared = AutomationScheduler()

    // MARK: - Published Properties (synced with AppSettings)

    @Published var dailyCleanupEnabled: Bool
    @Published var dailyCleanupTime: String // "03:00"
    @Published var weeklySecurityScanEnabled: Bool
    @Published var weeklySecurityScanDay: Int // 1-7 (Sunday = 1)

    // MARK: - Internal State

    private var timers: [String: DispatchSourceTimer] = [:]
    private let workQueue = DispatchQueue(label: "com.pulse.automation.scheduler", qos: .utility)
    private let settings = AppSettings.shared
    private let optimizer = ComprehensiveOptimizer.shared
    private let securityScanner = SecurityScanner.shared

    // Prevent infinite loops in two-way sync
    private var isSyncingSettings = false

    // MARK: - Initialization

    private init() {
        self.dailyCleanupEnabled = settings.dailyCleanupEnabled
        self.dailyCleanupTime = settings.dailyCleanupTime
        self.weeklySecurityScanEnabled = settings.weeklySecurityScanEnabled
        self.weeklySecurityScanDay = settings.weeklySecurityScanDay

        setupSettingsSync()
        startMonitoring()
    }

    // MARK: - Settings Sync

    private func setupSettingsSync() {
        // Sync daily cleanup settings (AppSettings -> Scheduler)
        settings.$dailyCleanupEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.dailyCleanupEnabled = enabled
                self.updateScheduledJobs()
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$dailyCleanupTime
            .sink { [weak self] time in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.dailyCleanupTime = time
                self.updateScheduledJobs()
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$weeklySecurityScanEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.weeklySecurityScanEnabled = enabled
                self.updateScheduledJobs()
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$weeklySecurityScanDay
            .sink { [weak self] day in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.weeklySecurityScanDay = day
                self.updateScheduledJobs()
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        // Sync scheduler changes back to AppSettings (Scheduler -> AppSettings)
        $dailyCleanupEnabled
            .dropFirst() // Skip initial value to avoid loop
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.dailyCleanupEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $dailyCleanupTime
            .dropFirst()
            .sink { [weak self] time in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.dailyCleanupTime = time
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $weeklySecurityScanEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.weeklySecurityScanEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $weeklySecurityScanDay
            .dropFirst()
            .sink { [weak self] day in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.weeklySecurityScanDay = day
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public Methods

    /// Start all scheduled jobs
    func startMonitoring() {
        scheduleDailyCleanup(at: dailyCleanupTime)
        scheduleWeeklySecurity(on: weeklySecurityScanDay)
    }

    /// Cancel all scheduled jobs
    func cancelAllScheduledJobs() {
        timers.values.forEach { $0.cancel() }
        timers.removeAll()
    }

    /// Update scheduled jobs when settings change
    func updateScheduledJobs() {
        cancelAllScheduledJobs()
        startMonitoring()
    }

    // MARK: - Scheduling

    /// Schedule daily cleanup at specified time
    func scheduleDailyCleanup(at time: String) {
        guard dailyCleanupEnabled else {
            cancelTimer(forKey: "dailyCleanup")
            return
        }

        let nextFireTime = calculateNextFireTime(for: time, weekday: nil)
        scheduleTimer(forKey: "dailyCleanup", fireAt: nextFireTime, interval: 86400) { [weak self] in
            self?.runScheduledCleanup()
        }
    }

    /// Schedule weekly security scan on specified day
    func scheduleWeeklySecurity(on day: Int) {
        guard weeklySecurityScanEnabled else {
            cancelTimer(forKey: "weeklySecurity")
            return
        }

        let nextFireTime = calculateNextFireTime(for: dailyCleanupTime, weekday: day)
        scheduleTimer(forKey: "weeklySecurity", fireAt: nextFireTime, interval: 604800) { [weak self] in
            self?.runScheduledSecurityScan()
        }
    }

    // MARK: - Timer Management

    private func scheduleTimer(forKey key: String, fireAt date: Date, interval: TimeInterval, action: @escaping () -> Void) {
        cancelTimer(forKey: key)

        let timer = DispatchSource.makeTimerSource(queue: workQueue)
        let deadline = DispatchTime.now() + .seconds(Int(date.timeIntervalSinceNow))
        timer.schedule(deadline: deadline, repeating: .seconds(Int(interval)), leeway: .seconds(60))
        timer.setEventHandler {
            action()
        }
        timer.resume()

        timers[key] = timer
    }

    private func cancelTimer(forKey key: String) {
        timers[key]?.cancel()
        timers.removeValue(forKey: key)
    }

    // MARK: - Time Calculation

    /// Calculate next fire time based on target time and optional weekday
    private func calculateNextFireTime(for time: String, weekday: Int?) -> Date {
        let components = parseTime(time)
        let calendar = Calendar.current
        let now = Date()

        var targetComponents = calendar.dateComponents([.year, .month, .day], from: now)
        targetComponents.hour = components.hour
        targetComponents.minute = components.minute
        targetComponents.second = 0

        guard var targetDate = calendar.date(from: targetComponents) else {
            return now.addingTimeInterval(60) // Fallback: 1 minute from now
        }

        // Handle weekday for weekly jobs
        if let weekday = weekday {
            let currentWeekday = calendar.component(.weekday, from: targetDate)
            var daysUntilTarget = weekday - currentWeekday

            // If today is the target day but time has passed, add 7 days
            if daysUntilTarget == 0 && targetDate <= now {
                daysUntilTarget = 7
            } else if daysUntilTarget < 0 || (daysUntilTarget == 0 && targetDate <= now) {
                daysUntilTarget += 7
            } else if daysUntilTarget == 0 && targetDate > now {
                // Today is the day and time hasn't passed yet
                return targetDate
            }

            targetDate = calendar.date(byAdding: .day, value: daysUntilTarget, to: targetDate) ?? targetDate
        } else {
            // Daily job: if time has passed today, schedule for tomorrow
            if targetDate <= now {
                targetDate = calendar.date(byAdding: .day, value: 1, to: targetDate) ?? targetDate
            }
        }

        return targetDate
    }

    /// Parse time string (HH:MM) into hour and minute components
    private func parseTime(_ time: String) -> (hour: Int, minute: Int) {
        let components = time.split(separator: ":")
        let hour = Int(components.first ?? "0") ?? 0
        let minute = Int(components.last ?? "0") ?? 0
        return (hour, minute)
    }

    // MARK: - Job Execution

    /// Execute scheduled cleanup
    private func runScheduledCleanup() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            print("[AutomationScheduler] Running scheduled cleanup...")

            // Run cleanup with auto-confirmation for small jobs
            DispatchQueue.main.async {
                self.optimizer.scanForCleanup()

                // Auto-execute if under threshold
                if self.settings.autoCleanupEnabled,
                   let plan = self.optimizer.currentPlan,
                   plan.totalSizeMB < self.settings.autoCleanupThresholdMB {
                    self.optimizer.executeCleanup()
                    print("[AutomationScheduler] Auto-cleanup executed: \(plan.totalSizeMB)MB")
                } else {
                    // For large cleanups, just notify user
                    print("[AutomationScheduler] Cleanup scan complete: \(self.optimizer.currentPlan?.totalSizeMB ?? 0)MB (manual confirmation required)")
                }
            }
        }
    }

    /// Execute scheduled security scan
    private func runScheduledSecurityScan() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            print("[AutomationScheduler] Running scheduled security scan...")

            DispatchQueue.main.async {
                self.securityScanner.scan()
                print("[AutomationScheduler] Security scan complete")
            }
        }
    }
}
