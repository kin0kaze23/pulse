import Foundation
import UserNotifications
import AppKit

/// Handles memory alerts and notifications
class AlertManager: ObservableObject {
    static let shared = AlertManager()

    @Published var lastAlertLevel: MemoryPressureLevel = .normal
    @Published var activeAlerts: [AlertNotification] = []

    private var lastAlertTime: [Double: Date] = [:]
    private let settings = AppSettings.shared
    private let quietHoursManager = QuietHoursManager.shared

    // Sound preference — defaults to false (silent), user opts-in
    @Published var soundsEnabled: Bool {
        didSet { UserDefaults.standard.set(soundsEnabled, forKey: "alertSoundsEnabled") }
    }

    struct AlertNotification: Identifiable {
        let id = UUID()
        let threshold: AlertThreshold
        let memoryPercentage: Double
        let timestamp: Date
        var message: String {
            "Memory usage is at \(String(format: "%.1f", memoryPercentage))% — \(threshold.label) level"
        }
    }

    private init() {
        self.soundsEnabled = UserDefaults.standard.object(forKey: "alertSoundsEnabled") as? Bool ?? false
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    // MARK: - Permission

    func requestNotificationPermission() {
        guard Bundle.main.bundleIdentifier != nil else {
            print("Notifications require a proper app bundle. Alerts will use sounds only.")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            }
        }
    }

    // MARK: - Check Thresholds

    func checkThresholds(memoryPercentage: Double) {
        guard settings.notificationsEnabled else { return }

        for threshold in settings.alertThresholds {
            guard threshold.isEnabled else { continue }

            if memoryPercentage >= threshold.percentage {
                // Check cooldown
                if let lastTime = lastAlertTime[threshold.percentage] {
                    let cooldownSeconds = Double(settings.alertCooldownMinutes) * 60.0
                    if Date().timeIntervalSince(lastTime) < cooldownSeconds {
                        continue
                    }
                }

                // Fire alert
                fireAlert(threshold: threshold, memoryPercentage: memoryPercentage)
                lastAlertTime[threshold.percentage] = Date()
            }
        }

        // Swap alerts (separate from memory percentage)
        checkSwapAlerts()

        // Update pressure level
        let newLevel: MemoryPressureLevel
        if memoryPercentage >= 95 {
            newLevel = .critical
        } else if memoryPercentage >= 85 {
            newLevel = .warning
        } else {
            newLevel = .normal
        }

        if newLevel != lastAlertLevel {
            lastAlertLevel = newLevel
        }
    }

    // MARK: - Swap Alerts

    private func checkSwapAlerts() {
        guard let mem = SystemMemoryMonitor.shared.currentMemory else { return }

        let swapGB = mem.swapUsedGB
        let swapKey: Double = -1 // sentinel for swap alerts

        if swapGB > 5 {
            if let lastTime = lastAlertTime[swapKey] {
                if Date().timeIntervalSince(lastTime) < 300 { return } // 5min cooldown
            }
            fireSwapAlert(swapGB: swapGB, level: "Critical")
            lastAlertTime[swapKey] = Date()
        } else if swapGB > 2 {
            if let lastTime = lastAlertTime[swapKey] {
                if Date().timeIntervalSince(lastTime) < 600 { return } // 10min cooldown
            }
            fireSwapAlert(swapGB: swapGB, level: "Warning")
            lastAlertTime[swapKey] = Date()
        }
    }

    private func fireSwapAlert(swapGB: Double, level: String) {
        // No programmatic sounds — only notification alerts (silent by default)
        let message = "Swap usage is \(String(format: "%.1f", swapGB)) GB — \(level). Your Mac may be slowing down."

        if Bundle.main.bundleIdentifier != nil {
            let content = UNMutableNotificationContent()
            content.title = "⚠️ Swap Alert — \(level)"
            content.body = message
            content.sound = nil // Silent — user controls notification sounds in System Settings

            let request = UNNotificationRequest(
                identifier: "swap-alert-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(request) { _ in }
        }
    }

    // MARK: - Fire Alert

    private func fireAlert(threshold: AlertThreshold, memoryPercentage: Double) {
        let notification = AlertNotification(
            threshold: threshold,
            memoryPercentage: memoryPercentage,
            timestamp: Date()
        )

        DispatchQueue.main.async {
            self.activeAlerts.insert(notification, at: 0)
            if self.activeAlerts.count > 50 {
                self.activeAlerts.removeLast()
            }
        }

        // No programmatic sounds — all alerts are silent notifications
        // System notification sounds are controlled by the user in macOS Notification Center

        if threshold.notificationEnabled {
            sendNotification(notification: notification, playSound: false)
        }
    }

    // MARK: - macOS Notification

    private func sendNotification(notification: AlertNotification, playSound: Bool = false) {
        // Check quiet hours - suppress non-critical notifications
        let isCritical = notification.threshold.percentage >= 95
        if quietHoursManager.shouldSuppressNotification(isCritical: isCritical) {
            print("[AlertManager] Notification suppressed during quiet hours: \(notification.threshold.label)")
            return
        }

        // Use UNUserNotificationCenter exclusively (NSUserNotification is deprecated)
        let content = UNMutableNotificationContent()
        content.title = "⚠️ Memory Alert — \(notification.threshold.label)"
        content.body = notification.message
        content.sound = playSound ? .default : nil
        content.categoryIdentifier = "MEMORY_ALERT"

        // Find top process to include in notification
        let topProcess = ProcessMemoryMonitor.shared.topProcesses.first
        if let process = topProcess {
            content.subtitle = "Top consumer: \(process.name) (\(String(format: "%.1f", process.memoryMB)) MB)"
        }

        let request = UNNotificationRequest(
            identifier: "memory-alert-\(notification.threshold.percentage)-\(UUID().uuidString)",
            content: content,
            trigger: nil // Immediate
        )

        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Notification error: \(error)")
            }
        }
    }

    // MARK: - Clear Alerts

    func clearAlerts() {
        activeAlerts.removeAll()
    }

    func clearOldAlerts(olderThan minutes: Int) {
        let cutoff = Date().addingTimeInterval(-Double(minutes) * 60)
        activeAlerts.removeAll { $0.timestamp < cutoff }
    }

    // MARK: - Proactive Recommendations

    func maybeRecommendClosing(process: ProcessMemoryInfo) {
        guard settings.notificationsEnabled else { return }
        guard process.isSafeToClose, process.memoryGB > 1.5 else { return }

        let key = -100 - Double(process.id)
        if let last = lastAlertTime[key], Date().timeIntervalSince(last) < 1800 {
            return
        }
        lastAlertTime[key] = Date()

        guard Bundle.main.bundleIdentifier != nil else { return }
        let content = UNMutableNotificationContent()
        content.title = "Suggestion: close a non-essential app"
        content.body = "\(process.name) is using \(String(format: "%.1f", process.memoryGB)) GB and has no visible windows. Closing it may improve responsiveness."
        content.sound = nil

        let request = UNNotificationRequest(
            identifier: "suggest-close-\(process.id)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    // MARK: - Disk Space Alerts

    private var lastDiskAlertTime: Date?

    func checkDiskSpace(freeGB: Double) {
        guard settings.notificationsEnabled else { return }
        guard settings.diskSpaceGuardianEnabled else { return }

        let warningThreshold = settings.diskWarningThresholdGB
        let criticalThreshold = settings.diskCriticalThresholdGB

        if freeGB <= criticalThreshold {
            fireDiskAlert(level: .critical, freeGB: freeGB)
        } else if freeGB <= warningThreshold {
            fireDiskAlert(level: .warning, freeGB: freeGB)
        }
    }

    private func fireDiskAlert(level: DiskHealthLevel, freeGB: Double) {
        // Check cooldown (5 min for critical, 15 min for warning)
        let cooldownSeconds: Double = level == .critical ? 300 : 900
        if let lastTime = lastDiskAlertTime, Date().timeIntervalSince(lastTime) < cooldownSeconds {
            return
        }
        lastDiskAlertTime = Date()

        // Check quiet hours - suppress non-critical alerts
        let isCritical = level == .critical
        if quietHoursManager.shouldSuppressNotification(isCritical: isCritical) {
            print("[AlertManager] Disk alert suppressed during quiet hours: \(level.rawValue)")
            return
        }

        // Send notification
        let content = UNMutableNotificationContent()
        content.title = level == .critical ? "⚠️ Critical: Disk Space Low" : "⚠️ Warning: Disk Space Low"
        content.body = "Only \(String(format: "%.1f", freeGB)) GB free. \(cleanupRecommendation(for: level))"
        content.sound = level == .critical ? .default : nil
        content.categoryIdentifier = "DISK_SPACE_ALERT"

        let request = UNNotificationRequest(
            identifier: "disk-space-\(level.rawValue)-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func cleanupRecommendation(for level: DiskHealthLevel) -> String {
        switch level {
        case .critical:
            return "Auto-cleanup will run if enabled."
        case .warning:
            return "Consider running cleanup from Pulse menu."
        case .healthy:
            return ""
        }
    }
}
