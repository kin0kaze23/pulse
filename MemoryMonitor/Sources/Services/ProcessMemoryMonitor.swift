import Foundation
import AppKit
import Darwin

/// Monitors per-process memory usage
class ProcessMemoryMonitor: ObservableObject {
    static let shared = ProcessMemoryMonitor()

    @Published var topProcesses: [ProcessMemoryInfo] = []
    @Published var allProcesses: [ProcessMemoryInfo] = []

    private init() {}

    // MARK: - Refresh Process List

    func refresh(topN: Int = 20) {
        let processes = getAllProcesses()
        let sorted = processes.sorted()
        DispatchQueue.main.async {
            self.allProcesses = sorted
            self.topProcesses = Array(sorted.prefix(topN))
        }
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
        // Get process name
        var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_name(pid, &nameBuffer, UInt32(MAXPATHLEN))
        let name = String(cString: nameBuffer)

        guard !name.isEmpty else { return nil }

        // Get process path
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        let path = String(cString: pathBuffer)

        // Get task info for memory
        var taskInfo = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size / MemoryLayout<natural_t>.size)

        let kernReturn = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        guard kernReturn == KERN_SUCCESS else { return nil }

        let residentBytes = UInt64(taskInfo.phys_footprint)
        let percentage = totalMemory > 0 ? Double(residentBytes) / Double(totalMemory) * 100.0 : 0

        // Get CPU usage
        var cpuInfo = task_basic_info()
        var cpuCount = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size / MemoryLayout<natural_t>.size)

        let _ = withUnsafeMutablePointer(to: &cpuInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(cpuCount)) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &cpuCount)
            }
        }

        // Skip very small processes (kernel threads, etc.)
        guard residentBytes > 1024 * 1024 else { return nil } // > 1MB

        // Skip our own process
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        return ProcessMemoryInfo(
            id: pid,
            name: name,
            memoryBytes: residentBytes,
            memoryPercentage: percentage,
            cpuPercentage: 0, // CPU requires sampling over time
            path: path.isEmpty ? nil : path
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

    // MARK: - App Icon

    func iconForProcess(pid: Int32) -> NSImage? {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.processIdentifier == pid }) else {
            return nil
        }
        return app.icon
    }
}
