import Foundation
import Combine

/// Manages quiet hours for suppressing non-critical notifications during user-specified time ranges
class QuietHoursManager: ObservableObject {
    static let shared = QuietHoursManager()

    // MARK: - Published Properties (synced with AppSettings)

    @Published var quietHoursEnabled: Bool
    @Published var quietHoursStart: String // "22:00"
    @Published var quietHoursEnd: String   // "08:00"
    @Published var allowCriticalAlerts: Bool

    // MARK: - Internal State

    private var timer: Timer?
    private let settings = AppSettings.shared
    private var cancellables = Set<AnyCancellable>()

    // Prevent infinite loops in two-way sync
    private var isSyncingSettings = false

    // MARK: - Initialization

    private init() {
        self.quietHoursEnabled = settings.quietHoursEnabled
        self.quietHoursStart = settings.quietHoursStart
        self.quietHoursEnd = settings.quietHoursEnd
        self.allowCriticalAlerts = settings.allowCriticalAlerts

        setupSettingsSync()
    }

    // MARK: - Settings Sync

    private func setupSettingsSync() {
        // Sync AppSettings -> Manager
        settings.$quietHoursEnabled
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.quietHoursEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$quietHoursStart
            .sink { [weak self] time in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.quietHoursStart = time
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$quietHoursEnd
            .sink { [weak self] time in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.quietHoursEnd = time
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        settings.$allowCriticalAlerts
            .sink { [weak self] allowed in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.allowCriticalAlerts = allowed
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        // Sync Manager -> AppSettings (two-way sync)
        $quietHoursEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.quietHoursEnabled = enabled
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $quietHoursStart
            .dropFirst()
            .sink { [weak self] time in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.quietHoursStart = time
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $quietHoursEnd
            .dropFirst()
            .sink { [weak self] time in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.quietHoursEnd = time
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)

        $allowCriticalAlerts
            .dropFirst()
            .sink { [weak self] allowed in
                guard let self = self else { return }
                guard !self.isSyncingSettings else { return }
                self.isSyncingSettings = true
                self.settings.allowCriticalAlerts = allowed
                self.isSyncingSettings = false
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Start monitoring quiet hours (called by MemoryMonitorManager)
    func startMonitoring() {
        // Check quiet hours status every minute
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.objectWillChange.send() // Notify UI of status change
        }
    }

    /// Stop monitoring
    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    /// Check if currently in quiet hours
    func isQuietHours() -> Bool {
        guard quietHoursEnabled else { return false }

        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let start = parseTime(quietHoursStart)
        let end = parseTime(quietHoursEnd)

        // Handle overnight ranges (e.g., 22:00 - 08:00)
        if start.hour > end.hour || (start.hour == end.hour && start.minute > end.minute) {
            // Overnight: after start OR before end
            return (now.hour ?? 0) > start.hour || (now.hour ?? 0) < end.hour ||
                   ((now.hour ?? 0) == start.hour && (now.minute ?? 0) >= start.minute) ||
                   ((now.hour ?? 0) == end.hour && (now.minute ?? 0) < end.minute)
        } else {
            // Same day: between start and end
            let currentTime = (now.hour ?? 0) * 60 + (now.minute ?? 0)
            let startTime = start.hour * 60 + start.minute
            let endTime = end.hour * 60 + end.minute

            return currentTime >= startTime && currentTime <= endTime
        }
    }

    /// Check if notification should be suppressed
    func shouldSuppressNotification(isCritical: Bool = false) -> Bool {
        guard isQuietHours() else { return false }

        // Critical alerts may still fire during quiet hours if enabled
        if isCritical && allowCriticalAlerts {
            return false
        }

        return true
    }

    // MARK: - Helper Methods

    /// Parse time string (HH:MM) into hour and minute components
    private func parseTime(_ time: String) -> (hour: Int, minute: Int) {
        let components = time.split(separator: ":")
        let hour = Int(components.first ?? "0") ?? 0
        let minute = Int(components.last ?? "0") ?? 0
        return (hour, minute)
    }

    /// Get formatted time range string for UI display
    func getTimeRangeString() -> String {
        "\(quietHoursStart) - \(quietHoursEnd)"
    }

    /// Check if quiet hours will start soon (within 15 minutes)
    func willStartSoon() -> Bool {
        guard quietHoursEnabled else { return false }

        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let start = parseTime(quietHoursStart)

        let currentTime = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let startTime = start.hour * 60 + start.minute

        // Check if within 15 minutes before start
        let minutesUntilStart = startTime - currentTime
        return minutesUntilStart > 0 && minutesUntilStart <= 15
    }

    /// Check if quiet hours will end soon (within 15 minutes)
    func willEndSoon() -> Bool {
        guard quietHoursEnabled else { return false }
        guard isQuietHours() else { return false }

        let now = Calendar.current.dateComponents([.hour, .minute], from: Date())
        let end = parseTime(quietHoursEnd)

        let currentTime = (now.hour ?? 0) * 60 + (now.minute ?? 0)
        let endTime = end.hour * 60 + end.minute

        // Handle overnight case
        let adjustedEndTime = endTime < currentTime ? endTime + 24 * 60 : endTime
        let minutesUntilEnd = adjustedEndTime - currentTime

        return minutesUntilEnd > 0 && minutesUntilEnd <= 15
    }
}
