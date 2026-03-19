import Foundation
import UserNotifications
import AppKit

/// Handles memory alerts and notifications
class AlertManager: ObservableObject {
    static let shared = AlertManager()

    @Published var lastAlertLevel: MemoryPressureLevel = .normal
    @Published var activeAlerts: [AlertNotification] = []

    private var lastAlertTime: [Double: Date] = [:] // threshold percentage -> last alert time
    private let settings = AppSettings.shared

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
        // Defer notification setup - will be called later
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

        // Play sound
        if threshold.soundEnabled {
            NSSound.beep()
            if threshold.percentage >= 95 {
                NSSound(named: "Sosumi")?.play()
            }
        }

        // Send notification
        if threshold.notificationEnabled {
            sendNotification(notification: notification)
        }
    }

    // MARK: - macOS Notification

    private func sendNotification(notification: AlertNotification) {
        // Check if we have a proper bundle (required for UNUserNotificationCenter)
        guard Bundle.main.bundleIdentifier != nil else {
            // Fall back to NSUserNotification (deprecated but works without bundle)
            let userNotification = NSUserNotification()
            userNotification.title = "⚠️ Memory Alert — \(notification.threshold.label)"
            userNotification.subtitle = notification.message
            userNotification.soundName = notification.threshold.soundEnabled ? NSUserNotificationDefaultSoundName : nil
            NSUserNotificationCenter.default.deliver(userNotification)
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "⚠️ Memory Alert — \(notification.threshold.label)"
        content.body = notification.message
        content.sound = notification.threshold.soundEnabled ? .default : nil
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
}
