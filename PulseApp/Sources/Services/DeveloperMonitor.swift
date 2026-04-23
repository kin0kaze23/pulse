import Foundation
import AppKit
import Darwin

/// Detects development-specific processes: opencode, browsers, and monitors swap/DB size
class DeveloperMonitor: ObservableObject {
    static let shared = DeveloperMonitor()

    // MARK: - Published State (all UI updates on main thread)

    @Published var opencodeProcesses: [DevProcess] = []
    @Published var opencodeTotalMB: Double = 0
    @Published var hasStandaloneSessions: Bool = false
    @Published var hasServeRunning: Bool = false
    @Published var servePort: String = ""

    @Published var browserTabCount: Int = 0
    @Published var browserTotalMB: Double = 0
    @Published var browsers: [BrowserInfo] = []

    @Published var swapUsedGB: Double = 0
    @Published var swapTotalGB: Double = 0

    @Published var opencodeDBSizeMB: Double = 0
    @Published var opencodeBackupSizeMB: Double = 0

    @Published var isRefreshing: Bool = false

    // MARK: - Models

    struct DevProcess: Identifiable {
        let id: Int32
        let name: String
        let memoryMB: Double
        let type: ProcessType
        let command: String

        enum ProcessType: String {
            case serve = "serve"
            case attach = "attach"
            case standalone = "standalone"
        }

        var typeLabel: String {
            switch type {
            case .serve: return "Server"
            case .attach: return "Client"
            case .standalone: return "Standalone"
            }
        }
    }

    struct BrowserInfo: Identifiable {
        let id = UUID()
        let name: String
        let processCount: Int
        let totalMB: Double
    }

    // MARK: - Private

    private var refreshTimer: Timer?
    private let workQueue = DispatchQueue(label: "com.memorymonitor.developer", qos: .utility)
    private init() {}

    // MARK: - Start / Stop

    func start(interval: TimeInterval = 5) {
        refresh()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    func stop() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    // MARK: - Refresh (all work on background queue)

    func refresh() {
        guard !isRefreshing else { return }
        DispatchQueue.main.async { self.isRefreshing = true }

        workQueue.async { [weak self] in
            guard let self else { return }

            // 1. Swap (fast, sysctl call)
            let (swapUsed, swapTotal) = self.readSwap()

            // 2. Single ps call for all process data
            let psOutput = self.runPS(args: ["-axo", "pid=,rss=,command="])

            // 3. Parse opencode from ps output
            let (procs, totalMB, hasStandalone, hasServe, port) = self.parseOpencode(from: psOutput)

            // 4. Parse browsers from same ps output
            let (browsers, browserCount, browserMB) = self.parseBrowsers(from: psOutput)

            // 5. DB size (fast file stat)
            let (dbMB, backupMB) = self.readDBSize()

            // 6. Publish all at once on main thread
            DispatchQueue.main.async {
                self.swapUsedGB = swapUsed
                self.swapTotalGB = swapTotal
                self.opencodeProcesses = procs
                self.opencodeTotalMB = totalMB
                self.hasStandaloneSessions = hasStandalone
                self.hasServeRunning = hasServe
                self.servePort = port
                self.browsers = browsers
                self.browserTabCount = browserCount
                self.browserTotalMB = browserMB
                self.opencodeDBSizeMB = dbMB
                self.opencodeBackupSizeMB = backupMB
                self.isRefreshing = false
            }
        }
    }

    // MARK: - Swap (read from SystemMemoryMonitor to avoid duplicate sysctl)

    private func readSwap() -> (used: Double, total: Double) {
        // Read from SystemMemoryMonitor instead of duplicating sysctl call
        if let memory = SystemMemoryMonitor.shared.currentMemory {
            let gb = 1024.0 * 1024.0 * 1024.0
            return (memory.swapUsedGB, Double(memory.swapTotalBytes) / gb)
        }
        // Fallback to sysctl if SystemMemoryMonitor hasn't loaded yet (race condition on startup)
        var swapInfo = xsw_usage()
        var sizeOfSwapInfo = MemoryLayout<xsw_usage>.size
        guard sysctlbyname("vm.swapusage", &swapInfo, &sizeOfSwapInfo, nil, 0) == 0 else {
            return (0, 0)
        }
        let gb = 1024.0 * 1024.0 * 1024.0
        return (Double(swapInfo.xsu_used) / gb, Double(swapInfo.xsu_total) / gb)
    }

    // MARK: - Process Execution (safe background)

    private func runPS(args: [String]) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = args
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            // Use a timeout to prevent hanging
            let finished = task.waitUntilExit(timeout: 5)
            if !finished {
                task.terminate()
                return ""
            }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            return ""
        }
    }

    // MARK: - Parse OpenCode

    private func parseOpencode(from output: String) -> (
        procs: [DevProcess], totalMB: Double, hasStandalone: Bool, hasServe: Bool, port: String
    ) {
        var processes: [DevProcess] = []
        var totalMB: Double = 0
        var hasStandalone = false
        var hasServe = false
        var port = ""

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.contains("opencode") else { continue }
            guard !trimmed.contains("/bin/zsh") && !trimmed.contains("grep") else { continue }

            let parts = trimmed.split(separator: " ", maxSplits: 2, omittingEmptySubsequences: true)
            guard parts.count >= 3,
                  let pid = Int32(parts[0]),
                  let rssKB = Double(parts[1]) else { continue }

            let command = String(parts[2])
            let memMB = rssKB / 1024

            let type: DevProcess.ProcessType
            if command.contains("opencode serve") {
                type = .serve
                hasServe = true
                if let range = command.range(of: "--port ") {
                    let afterPort = command[range.upperBound...]
                    port = String(afterPort.prefix(while: { $0.isNumber }))
                }
            } else if command.contains("opencode attach") {
                type = .attach
            } else {
                type = .standalone
                hasStandalone = true
            }

            processes.append(DevProcess(
                id: pid,
                name: "opencode",
                memoryMB: memMB,
                type: type,
                command: command
            ))
            totalMB += memMB
        }

        return (processes.sorted { $0.memoryMB > $1.memoryMB }, totalMB, hasStandalone, hasServe, port)
    }

    // MARK: - Parse Browsers

    private func parseBrowsers(from output: String) -> (
        browsers: [BrowserInfo], count: Int, totalMB: Double
    ) {
        var browserData: [String: (count: Int, mb: Double)] = [:]
        var totalTabs = 0
        var totalMB: Double = 0

        let browserPatterns: [(name: String, pattern: String)] = [
            ("Brave", "Brave Browser Helper (Renderer)"),
            ("Chrome", "Google Chrome Helper (Renderer)"),
            ("Firefox", "firefox"),
            ("Safari", "Safari"),
        ]

        for line in output.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for browser in browserPatterns {
                if trimmed.contains(browser.pattern) {
                    let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    if parts.count >= 1, let rssKB = Double(parts[0]) {
                        let memMB = rssKB / 1024
                        var entry = browserData[browser.name] ?? (count: 0, mb: 0)
                        entry.count += 1
                        entry.mb += memMB
                        browserData[browser.name] = entry
                        totalTabs += 1
                        totalMB += memMB
                    }
                }
            }
        }

        let browserInfos = browserData.map { name, data in
            BrowserInfo(name: name, processCount: data.count, totalMB: data.mb)
        }.sorted { $0.totalMB > $1.totalMB }

        return (browserInfos, totalTabs, totalMB)
    }

    // MARK: - DB Size (fast file stat)

    private func readDBSize() -> (dbMB: Double, backupMB: Double) {
        let baseDir = ("~/.local/share/opencode/" as NSString).expandingTildeInPath
        let dbPath = baseDir + "/opencode.db"

        var dbMB: Double = 0
        if let attrs = try? FileManager.default.attributesOfItem(atPath: dbPath),
           let size = attrs[.size] as? UInt64 {
            dbMB = Double(size) / (1024 * 1024)
        }

        var backupMB: Double = 0
        if let contents = try? FileManager.default.contentsOfDirectory(atPath: baseDir) {
            for item in contents where item.hasPrefix("opencode.db.backup") {
                let fullPath = baseDir + "/" + item
                if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
                   let size = attrs[.size] as? UInt64 {
                    backupMB += Double(size) / (1024 * 1024)
                }
            }
        }

        return (dbMB, backupMB)
    }

    // MARK: - Actions

    func killStandaloneSessions() {
        workQueue.async {
            for proc in self.opencodeProcesses where proc.type == .standalone {
                kill(proc.id, SIGTERM)
            }
            Thread.sleep(forTimeInterval: 1)
            self.refresh()
        }
    }

    func cleanOpencodeDB() {
        workQueue.async { [weak self] in
            guard let self else { return }
            let baseDir = ("~/.local/share/opencode/" as NSString).expandingTildeInPath
            let dbPath = baseDir + "/opencode.db"

            // Delete backup files
            if let contents = try? FileManager.default.contentsOfDirectory(atPath: baseDir) {
                for item in contents where item.hasPrefix("opencode.db.backup") {
                    try? FileManager.default.removeItem(atPath: baseDir + "/" + item)
                }
            }

            // Clean database — keep only 3 most recent sessions
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
            task.arguments = [dbPath, """
                DELETE FROM part WHERE session_id NOT IN (SELECT id FROM session ORDER BY time_updated DESC LIMIT 3);
                DELETE FROM session WHERE id NOT IN (SELECT id FROM session ORDER BY time_updated DESC LIMIT 3);
                DELETE FROM part WHERE session_id NOT IN (SELECT id FROM session);
                VACUUM;
            """]
            task.standardError = FileHandle.nullDevice
            try? task.run()
            _ = task.waitUntilExit(timeout: 30)

            Thread.sleep(forTimeInterval: 1)
            self.refresh()
        }
    }

    // MARK: - Computed Warnings

    var warnings: [DeveloperWarning] {
        var result: [DeveloperWarning] = []

        if swapUsedGB > 10 {
            result.append(DeveloperWarning(
                icon: "exclamationmark.triangle.fill",
                title: "High Swap Usage",
                detail: String(format: "%.1f GB swap — restart Mac to clear", swapUsedGB),
                severity: .critical,
                action: nil
            ))
        } else if swapUsedGB > 5 {
            result.append(DeveloperWarning(
                icon: "exclamationmark.triangle",
                title: "Moderate Swap",
                detail: String(format: "%.1f GB swap used", swapUsedGB),
                severity: .warning,
                action: nil
            ))
        }

        if opencodeDBSizeMB > 500 {
            result.append(DeveloperWarning(
                icon: "cylinder.fill",
                title: "OpenCode DB Bloated",
                detail: String(format: "%.0f MB — clean to free RAM", opencodeDBSizeMB),
                severity: .critical,
                action: .cleanDB
            ))
        } else if opencodeDBSizeMB > 100 {
            result.append(DeveloperWarning(
                icon: "cylinder",
                title: "OpenCode DB Growing",
                detail: String(format: "%.0f MB — consider cleaning soon", opencodeDBSizeMB),
                severity: .warning,
                action: .cleanDB
            ))
        }

        if hasStandaloneSessions {
            let standaloneMB = opencodeProcesses.filter { $0.type == .standalone }.reduce(0.0) { $0 + $1.memoryMB }
            result.append(DeveloperWarning(
                icon: "bolt.slash.fill",
                title: "Standalone Sessions Running",
                detail: String(format: "%.0f MB wasted — use serve+attach instead", standaloneMB),
                severity: .warning,
                action: .killStandalone
            ))
        }

        if browserTabCount > 30 {
            result.append(DeveloperWarning(
                icon: "macwindow.on.rectangle",
                title: "Too Many Browser Tabs",
                detail: "\(browserTabCount) tabs using \(String(format: "%.0f MB", browserTotalMB))",
                severity: .warning,
                action: nil
            ))
        }

        if opencodeBackupSizeMB > 100 {
            result.append(DeveloperWarning(
                icon: "trash.fill",
                title: "Old DB Backups",
                detail: String(format: "%.0f MB of backups on disk", opencodeBackupSizeMB),
                severity: .info,
                action: .cleanDB
            ))
        }

        return result
    }

    struct DeveloperWarning: Identifiable {
        let id = UUID()
        let icon: String
        let title: String
        let detail: String
        let severity: Severity
        let action: QuickAction?

        enum Severity {
            case info, warning, critical
        }

        enum QuickAction {
            case cleanDB, killStandalone
        }
    }
}

// MARK: - Process waitUntilExit with timeout

private extension Process {
    @discardableResult
    func waitUntilExit(timeout seconds: TimeInterval) -> Bool {
        let start = Date()
        while isRunning {
            if Date().timeIntervalSince(start) > seconds {
                return false
            }
            Thread.sleep(forTimeInterval: 0.05)
        }
        return true
    }
}
