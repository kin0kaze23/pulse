import Foundation

// MARK: - System Memory Info
struct SystemMemoryInfo: Identifiable {
    let id = UUID()
    let timestamp: Date

    // Physical memory
    let totalBytes: UInt64
    let usedBytes: UInt64
    let freeBytes: UInt64
    let cachedBytes: UInt64
    let compressedBytes: UInt64
    let wiredBytes: UInt64
    let activeBytes: UInt64
    let inactiveBytes: UInt64

    // Swap
    let swapUsedBytes: UInt64
    let swapTotalBytes: UInt64

    // App memory
    let appMemoryBytes: UInt64

    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0 }
        return Double(usedBytes) / Double(totalBytes) * 100.0
    }

    var totalGB: Double { Double(totalBytes) / (1024 * 1024 * 1024) }
    var usedGB: Double { Double(usedBytes) / (1024 * 1024 * 1024) }
    var freeGB: Double { Double(freeBytes) / (1024 * 1024 * 1024) }
    var cachedGB: Double { Double(cachedBytes) / (1024 * 1024 * 1024) }
    var swapUsedGB: Double { Double(swapUsedBytes) / (1024 * 1024 * 1024) }
    var appMemoryGB: Double { Double(appMemoryBytes) / (1024 * 1024 * 1024) }
    var compressedGB: Double { Double(compressedBytes) / (1024 * 1024 * 1024) }
    var wiredGB: Double { Double(wiredBytes) / (1024 * 1024 * 1024) }
}

// MARK: - Process Memory Info
struct ProcessMemoryInfo: Identifiable, Comparable {
    let id: Int32 // PID
    let name: String
    let memoryBytes: UInt64
    let memoryPercentage: Double
    let cpuPercentage: Double
    let path: String?

    var memoryMB: Double { Double(memoryBytes) / (1024 * 1024) }
    var memoryGB: Double { Double(memoryBytes) / (1024 * 1024 * 1024) }

    static func < (lhs: ProcessMemoryInfo, rhs: ProcessMemoryInfo) -> Bool {
        lhs.memoryBytes > rhs.memoryBytes
    }

    static func == (lhs: ProcessMemoryInfo, rhs: ProcessMemoryInfo) -> Bool {
        lhs.id == rhs.id
    }

    var hashValue: Int { Int(id) }
}

// MARK: - Memory Pressure Level
enum MemoryPressureLevel: String, Comparable {
    case normal = "Normal"
    case warning = "Warning"
    case critical = "Critical"

    var color: String {
        switch self {
        case .normal: return "green"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }

    static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        let order: [MemoryPressureLevel] = [.normal, .warning, .critical]
        return order.firstIndex(of: lhs)! < order.firstIndex(of: rhs)!
    }
}

// MARK: - Alert Threshold
struct AlertThreshold: Codable, Identifiable {
    let id: UUID
    var percentage: Double
    var isEnabled: Bool
    var label: String
    var soundEnabled: Bool
    var notificationEnabled: Bool

    init(percentage: Double, label: String, isEnabled: Bool = true, soundEnabled: Bool = true, notificationEnabled: Bool = true) {
        self.id = UUID()
        self.percentage = percentage
        self.label = label
        self.isEnabled = isEnabled
        self.soundEnabled = soundEnabled
        self.notificationEnabled = notificationEnabled
    }
}

// MARK: - Memory History Entry
struct MemoryHistoryEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let usedPercentage: Double
    let usedGB: Double
}
