import Foundation
import Darwin

/// Monitors system-wide memory statistics using low-level mach APIs
class SystemMemoryMonitor: ObservableObject {
    static let shared = SystemMemoryMonitor()

    @Published var currentMemory: SystemMemoryInfo?
    @Published var pressureLevel: MemoryPressureLevel = .normal
    @Published var memoryHistory: [MemoryHistoryEntry] = []
    @Published var isMonitoring = false

    private var timer: Timer?
    private let maxHistoryEntries = 1800 // ~60 min at 2s interval

    private init() {}

    // MARK: - Start / Stop

    func startMonitoring(interval: Double = 2.0) {
        stopMonitoring()
        isMonitoring = true

        // Immediate first read
        updateMemoryInfo()

        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.updateMemoryInfo()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
        isMonitoring = false
    }

    // MARK: - Core Memory Reading

    func updateMemoryInfo() {
        guard let info = readSystemMemory() else { return }

        DispatchQueue.main.async {
            self.currentMemory = info
            self.pressureLevel = self.calculatePressure(usedPercentage: info.usedPercentage)

            // Add to history
            let entry = MemoryHistoryEntry(
                timestamp: Date(),
                usedPercentage: info.usedPercentage,
                usedGB: info.usedGB
            )
            self.memoryHistory.append(entry)

            // Trim history
            let maxEntries = AppSettings.shared.historyDurationMinutes * 30 // 30 entries per minute at 2s
            if self.memoryHistory.count > maxEntries {
                self.memoryHistory.removeFirst(self.memoryHistory.count - maxEntries)
            }
        }
    }

    // MARK: - Mach VM Statistics (Low-Level)

    private func readSystemMemory() -> SystemMemoryInfo? {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let hostPort: mach_port_t = mach_host_self()
        let kernReturn = withUnsafeMutablePointer(to: &vmStats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(hostPort, HOST_VM_INFO64, $0, &count)
            }
        }

        guard kernReturn == KERN_SUCCESS else { return nil }

        let pageSize = UInt64(vm_kernel_page_size)

        // Get physical memory
        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0)

        let activeBytes = UInt64(vmStats.active_count) * pageSize
        let inactiveBytes = UInt64(vmStats.inactive_count) * pageSize
        let wiredBytes = UInt64(vmStats.wire_count) * pageSize
        let compressedBytes = UInt64(vmStats.compressor_page_count) * pageSize
        let freeBytes = UInt64(vmStats.free_count) * pageSize
        let speculativeBytes = UInt64(vmStats.speculative_count) * pageSize
        let purgeableBytes = UInt64(vmStats.purgeable_count) * pageSize

        // "Used" = active + wired + compressed (what is actually in use)
        let usedBytes = activeBytes + wiredBytes + compressedBytes
        // "App memory" = active - purgeable (approximation)
        let appMemoryBytes = activeBytes > purgeableBytes ? activeBytes - purgeableBytes : 0
        // "Cached" = inactive + speculative + purgeable
        let cachedBytes = inactiveBytes + speculativeBytes + purgeableBytes

        // Get swap info
        var swapInfo = xsw_usage()
        var swapSize = MemoryLayout<xsw_usage>.size
        sysctlbyname("vm.swapusage", &swapInfo, &swapSize, nil, 0)

        return SystemMemoryInfo(
            timestamp: Date(),
            totalBytes: physicalMemory,
            usedBytes: usedBytes,
            freeBytes: freeBytes,
            cachedBytes: cachedBytes,
            compressedBytes: compressedBytes,
            wiredBytes: wiredBytes,
            activeBytes: activeBytes,
            inactiveBytes: inactiveBytes,
            swapUsedBytes: swapInfo.xsu_used,
            swapTotalBytes: swapInfo.xsu_total,
            appMemoryBytes: appMemoryBytes
        )
    }

    // MARK: - Pressure Calculation

    private func calculatePressure(usedPercentage: Double) -> MemoryPressureLevel {
        if usedPercentage >= 95 {
            return .critical
        } else if usedPercentage >= 85 {
            return .warning
        }
        return .normal
    }

    // MARK: - History Utilities

    func historyForLast(minutes: Int) -> [MemoryHistoryEntry] {
        let cutoff = Date().addingTimeInterval(-Double(minutes) * 60)
        return memoryHistory.filter { $0.timestamp > cutoff }
    }

    func peakMemoryInLast(minutes: Int) -> MemoryHistoryEntry? {
        historyForLast(minutes: minutes).max(by: { $0.usedPercentage < $1.usedPercentage })
    }

    func averageMemoryInLast(minutes: Int) -> Double {
        let entries = historyForLast(minutes: minutes)
        guard !entries.isEmpty else { return 0 }
        return entries.map(\.usedPercentage).reduce(0, +) / Double(entries.count)
    }
}
