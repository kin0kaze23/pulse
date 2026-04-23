import Foundation
import AppKit
import Darwin

/// Monitors per-process memory usage
class ProcessMemoryMonitor: ObservableObject {
    static let shared = ProcessMemoryMonitor()

    @Published var topProcesses: [ProcessMemoryInfo] = []
    @Published var allProcesses: [ProcessMemoryInfo] = []

    // Icon cache — avoids repeated NSWorkspace scans
    private var iconCache: [Int32: NSImage] = [:]
    private var iconCacheTimestamp: Date = .distantPast
    private let iconCacheLifetime: TimeInterval = 30 // refresh cache every 30s

    // Safe-to-close cache — apps with visible windows
    private var appsWithWindows: Set<Int32> = []

    private init() {}

    // MARK: - Refresh Process List

    func refresh(topN: Int = 20) {
        // Run heavy work on background queue to avoid blocking main thread
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            // Update apps-with-windows cache
            self.refreshAppsWithWindows()

            let processes = self.getAllProcesses()
            let sorted = processes.sorted()
            let activePIDs = Set(sorted.map(\.id))
            self.pruneIconCache(activePIDs: activePIDs)
            
            DispatchQueue.main.async {
                self.allProcesses = sorted
                self.topProcesses = Array(sorted.prefix(topN))
            }
        }
    }

    /// Find which app PIDs have visible windows using CGWindowList
    private func refreshAppsWithWindows() {
        var pids = Set<Int32>()

        guard let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else { return }

        for window in windowList {
            if let ownerPID = window[kCGWindowOwnerPID as String] as? Int32 {
                pids.insert(ownerPID)
            }
        }

        appsWithWindows = pids
    }

    // MARK: - Get All Process Memory Info

    private func getAllProcesses() -> [ProcessMemoryInfo] {
        var processes: [ProcessMemoryInfo] = []

        // Get total physical memory for percentage calculation
        var physicalMemory: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &physicalMemory, &size, nil, 0)

        // Get list of all PIDs
        var count = proc_listallpids(nil, 0)
        guard count > 0 else { return [] }

        var pids = [Int32](repeating: 0, count: Int(count))
        count = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * Int(count)))

        for i in 0..<Int(count) {
            let pid = pids[i]
            guard pid > 0 else { continue }

            if let info = getProcessInfo(pid: pid, totalMemory: physicalMemory) {
                processes.append(info)
            }
        }

        return processes
    }

    // MARK: - Single Process Info

    private func getProcessInfo(pid: Int32, totalMemory: UInt64) -> ProcessMemoryInfo? {
        // Skip our own process
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        // Get process name
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_name(pid, &nameBuffer, UInt32(MAXPATHLEN))
        let name = String(cString: nameBuffer)

        guard !name.isEmpty else { return nil }

        // Get process path
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        let path = String(cString: pathBuffer)

        // Use proc_pidinfo with PROC_PIDTASKINFO to get memory for THIS specific process
        // (task_info with mach_task_self_ was wrong — it returned the app's own memory for every process)
        var taskInfo = proc_taskinfo()
        let procSize = MemoryLayout<proc_taskinfo>.size
        let bytesRead = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(procSize))

        guard bytesRead > 0 else { return nil }

        let residentBytes = UInt64(taskInfo.pti_resident_size)
        let percentage = totalMemory > 0 ? Double(residentBytes) / Double(totalMemory) * 100.0 : 0

        // Skip very small processes (kernel threads, etc.)
        guard residentBytes > 1024 * 1024 else { return nil } // > 1MB

        let safeToClose = !appsWithWindows.contains(pid)

        return ProcessMemoryInfo(
            id: pid,
            name: name,
            memoryBytes: residentBytes,
            memoryPercentage: percentage,
            cpuPercentage: 0, // CPU is tracked separately in CPUMonitor
            path: path.isEmpty ? nil : path,
            isSafeToClose: safeToClose
        )
    }

    // MARK: - Kill Process

    @discardableResult
    func killProcess(pid: Int32) -> Bool {
        let result = Darwin.kill(pid, SIGTERM)
        return result == 0
    }

    func forceKillProcess(pid: Int32) -> Bool {
        let result = Darwin.kill(pid, SIGKILL)
        return result == 0
    }

    // MARK: - Find Process by Name

    func findProcess(named name: String) -> ProcessMemoryInfo? {
        allProcesses.first { $0.name.localizedCaseInsensitiveContains(name) }
    }

    // MARK: - App Icon (cached)

    func iconForProcess(pid: Int32) -> NSImage? {
        // Return cached if still valid
        if let cached = iconCache[pid],
           Date().timeIntervalSince(iconCacheTimestamp) < iconCacheLifetime {
            return cached
        }

        // Rebuild cache if expired
        if Date().timeIntervalSince(iconCacheTimestamp) >= iconCacheLifetime {
            rebuildIconCache()
        }

        return iconCache[pid]
    }

    private func rebuildIconCache() {
        iconCache.removeAll()
        for app in NSWorkspace.shared.runningApplications {
            if let icon = app.icon {
                iconCache[app.processIdentifier] = icon
            }
        }
        iconCacheTimestamp = Date()
    }

    /// Remove stale entries from icon cache (call after refresh)
    private func pruneIconCache(activePIDs: Set<Int32>) {
        for pid in iconCache.keys where !activePIDs.contains(pid) {
            iconCache.removeValue(forKey: pid)
        }
    }
}
