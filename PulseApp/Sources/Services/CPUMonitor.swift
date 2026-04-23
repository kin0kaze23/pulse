import Foundation
import Darwin

/// Monitors system-wide and per-process CPU usage
class CPUMonitor: ObservableObject {
    static let shared = CPUMonitor()

    @Published var systemCPUPercentage: Double = 0
    @Published var userCPUPercentage: Double = 0
    @Published var idleCPUPercentage: Double = 100
    @Published var cpuHistory: [CPUHistoryEntry] = []
    @Published var topCPUProcesses: [CPUPerProcess] = []
    @Published var coreCount: Int = 0
    @Published var cpuName: String = ""

    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var previousProcessTicks: [Int32: UInt64] = [:]

    struct CPUHistoryEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let systemPercent: Double
        let userPercent: Double
        let idlePercent: Double
    }

    struct CPUPerProcess: Identifiable, Comparable {
        let id: Int32
        let name: String
        let cpuPercentage: Double
        let path: String?

        static func < (lhs: CPUPerProcess, rhs: CPUPerProcess) -> Bool {
            lhs.cpuPercentage > rhs.cpuPercentage
        }
    }

    private init() {
        // Get CPU info
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.ncpu", &coreCount, &size, nil, 0)

        var nameBuf = [CChar](repeating: 0, count: 256)
        size = 256
        sysctlbyname("machdep.cpu.brand_string", &nameBuf, &size, nil, 0)
        cpuName = String(cString: nameBuf)
    }

// MARK: - Update CPU Stats

    func update() {
        updateSystemCPU()
        // Don't update process CPU on every tick - it's expensive
        // Process CPU is updated separately via updateProcessCPU()
    }

    private func updateSystemCPU() {
        var cpuCount: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var msgCount: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &cpuCount, &cpuInfo, &msgCount)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return }

        var totalUser: UInt64 = 0
        var totalSystem: UInt64 = 0
        var totalIdle: UInt64 = 0
        var totalNice: UInt64 = 0

        for i in 0..<Int(cpuCount) {
            let offset = Int(CPU_STATE_MAX) * i
            totalUser += UInt64(info[offset + Int(CPU_STATE_USER)])
            totalSystem += UInt64(info[offset + Int(CPU_STATE_SYSTEM)])
            totalIdle += UInt64(info[offset + Int(CPU_STATE_IDLE)])
            totalNice += UInt64(info[offset + Int(CPU_STATE_NICE)])
        }

        let vmSize = MemoryLayout<integer_t>.size * Int(msgCount)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), vm_size_t(vmSize))

        if let prev = previousCPUTicks {
            let userDelta = Double(totalUser - prev.user)
            let systemDelta = Double(totalSystem - prev.system)
            let idleDelta = Double(totalIdle - prev.idle)
            let niceDelta = Double(totalNice - prev.nice)
            let totalDelta = userDelta + systemDelta + idleDelta + niceDelta

            if totalDelta > 0 {
                let userPct = (userDelta + niceDelta) / totalDelta * 100.0
                let systemPct = systemDelta / totalDelta * 100.0
                let idlePct = idleDelta / totalDelta * 100.0

                DispatchQueue.main.async {
                    self.userCPUPercentage = userPct
                    self.systemCPUPercentage = systemPct
                    self.idleCPUPercentage = idlePct

                    let entry = CPUHistoryEntry(
                        timestamp: Date(),
                        systemPercent: systemPct,
                        userPercent: userPct,
                        idlePercent: idlePct
                    )
                    self.cpuHistory.append(entry)
                    if self.cpuHistory.count > 300 {
                        self.cpuHistory.removeFirst(self.cpuHistory.count - 300)
                    }
                }
            }
        }

        previousCPUTicks = (totalUser, totalSystem, totalIdle, totalNice)
    }

    func updateProcessCPU() {
        var count = proc_listallpids(nil, 0)
        guard count > 0 else { return }

        var pids = [Int32](repeating: 0, count: Int(count))
        count = proc_listallpids(&pids, Int32(MemoryLayout<Int32>.size * Int(count)))

        var processes: [CPUPerProcess] = []
        var currentTicks: [Int32: UInt64] = [:]
        let myPID = ProcessInfo.processInfo.processIdentifier

        for i in 0..<Int(count) {
            let pid = pids[i]
            guard pid > 0, pid != myPID else { continue }

            // Get name
            var nameBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            proc_name(pid, &nameBuffer, UInt32(MAXPATHLEN))
            let name = String(cString: nameBuffer)
            guard !name.isEmpty else { continue }

            var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
            proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
            let path = String(cString: pathBuffer)

            // Use proc_pidinfo for CPU time (correct — reads target process, not self)
            var threadInfo = proc_taskinfo()
            let procSize = MemoryLayout<proc_taskinfo>.size
            let bytesRead = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &threadInfo, Int32(procSize))

            if bytesRead > 0 {
                let totalTicks = threadInfo.pti_total_user + threadInfo.pti_total_system
                currentTicks[pid] = totalTicks

                let cpuPct: Double
                if let prevTicks = previousProcessTicks[pid] {
                    let delta = Double(totalTicks - prevTicks)
                    cpuPct = delta / 1_000_000.0 // Convert from nanoseconds
                } else {
                    cpuPct = 0
                }

                if cpuPct > 0.5 { // Only include processes using noticeable CPU
                    processes.append(CPUPerProcess(
                        id: pid,
                        name: name,
                        cpuPercentage: cpuPct,
                        path: path.isEmpty ? nil : path
                    ))
                }
            }
        }

        previousProcessTicks = currentTicks

        DispatchQueue.main.async {
            self.topCPUProcesses = Array(processes.sorted().prefix(15))
        }
    }

    // MARK: - History

    func historyForLast(minutes: Int) -> [CPUHistoryEntry] {
        let cutoff = Date().addingTimeInterval(-Double(minutes) * 60)
        return cpuHistory.filter { $0.timestamp > cutoff }
    }

    func averageCPUInLast(minutes: Int) -> Double {
        let entries = historyForLast(minutes: minutes)
        guard !entries.isEmpty else { return 0 }
        let total = entries.map { $0.userPercent + $0.systemPercent }.reduce(0, +)
        return total / Double(entries.count)
    }
}
