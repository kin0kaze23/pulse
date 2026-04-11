import Foundation

// MARK: - Trigger Type

enum TriggerType: String, Codable, CaseIterable {
    case batteryLow = "battery_low"
    case memoryHigh = "memory_high"
    case thermalCritical = "thermal_critical"
    case dailyCleanup = "daily_cleanup"
    case weeklySecurityScan = "weekly_security_scan"
    case autoCleanup = "auto_cleanup"
    case manualCleanup = "manual_cleanup"
    case stopMemoryHog = "stop_memory_hog"

    var displayName: String {
        switch self {
        case .batteryLow: return "Low Battery"
        case .memoryHigh: return "High Memory"
        case .thermalCritical: return "Thermal Critical"
        case .dailyCleanup: return "Daily Cleanup"
        case .weeklySecurityScan: return "Weekly Security Scan"
        case .autoCleanup: return "Auto Cleanup"
        case .manualCleanup: return "Manual Cleanup"
        case .stopMemoryHog: return "Stop Memory Hog"
        }
    }

    var icon: String {
        switch self {
        case .batteryLow: return "battery.25"
        case .memoryHigh: return "memorychip"
        case .thermalCritical: return "thermometer.high"
        case .dailyCleanup: return "calendar.badge.clock"
        case .weeklySecurityScan: return "shield.checkered"
        case .autoCleanup: return "arrow.clockwise"
        case .manualCleanup: return "hand.raised"
        case .stopMemoryHog: return "xmark.circle"
        }
    }

    var category: TriggerCategory {
        switch self {
        case .batteryLow:
            return .system
        case .memoryHigh, .thermalCritical, .autoCleanup, .stopMemoryHog:
            return .automation
        case .dailyCleanup, .weeklySecurityScan:
            return .scheduled
        case .manualCleanup:
            return .manual
        }
    }
}

// MARK: - Trigger Category

enum TriggerCategory: String, Codable, CaseIterable {
    case system = "System"
    case automation = "Automation"
    case scheduled = "Scheduled"
    case manual = "Manual"
}

// MARK: - Trigger Event

struct TriggerEvent: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let type: TriggerType
    let value: Double? // e.g., memory percentage at trigger time
    let threshold: Double? // e.g., threshold that was set
    let freedMB: Double? // memory freed by cleanup
    let processName: String? // for stopMemoryHog
    let processID: Int32? // PID for stopMemoryHog
    let success: Bool
    let errorMessage: String?

    init(
        type: TriggerType,
        value: Double? = nil,
        threshold: Double? = nil,
        freedMB: Double? = nil,
        processName: String? = nil,
        processID: Int32? = nil,
        success: Bool = true,
        errorMessage: String? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.value = value
        self.threshold = threshold
        self.freedMB = freedMB
        self.processName = processName
        self.processID = processID
        self.success = success
        self.errorMessage = errorMessage
    }

    // Computed properties for display

    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }

    var formattedDuration: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }

    var freedMBFormatted: String {
        guard let mb = freedMB else { return "-" }
        return String(format: "%.1f MB", mb)
    }

    var valueFormatted: String {
        guard let val = value else { return "-" }
        return String(format: "%.0f%%", val)
    }
}

// MARK: - Trigger Statistics

struct TriggerStatistics {
    let totalEvents: Int
    let todayEvents: Int
    let weekEvents: Int
    let successfulEvents: Int
    let failedEvents: Int
    let totalFreedMB: Double

    var successRate: Double {
        guard totalEvents > 0 else { return 0 }
        return Double(successfulEvents) / Double(totalEvents) * 100
    }
}

// MARK: - Trigger Filter

enum TriggerFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case automation = "Automation"
    case scheduled = "Scheduled"
    case manual = "Manual"

    var category: TriggerCategory? {
        switch self {
        case .all, .today, .thisWeek:
            return nil
        case .automation:
            return .automation
        case .scheduled:
            return .scheduled
        case .manual:
            return .manual
        }
    }
}