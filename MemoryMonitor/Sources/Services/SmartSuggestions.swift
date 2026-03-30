import Foundation
import AppKit
import Darwin

/// Rules-Based Suggestions for System Optimization
/// Note: This is NOT AI-powered - it uses simple threshold-based rules
/// 
/// The suggestions are hardcoded if-then logic based on:
/// - Memory pressure thresholds
/// - Disk usage thresholds  
/// - Running process detection
/// - Browser tab counts (via AppleScript)
/// 
/// No machine learning, no CoreML, no adaptive behavior.
class SmartSuggestions: ObservableObject {
    static let shared = SmartSuggestions()

    @Published var suggestions: [Suggestion] = []
    @Published var lastUpdated: Date?
    @Published var isAnalyzing = false
    @Published var totalRecoverableGB: Double = 0

    struct Suggestion: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let icon: String
        let action: Action
        let priority: Priority
        let potentialSavings: String
        let category: Category

        enum Priority: Int, Comparable {
            case critical = 0
            case high = 1
            case medium = 2
            case low = 3

            var color: Color {
                switch self {
                case .critical: return .red
                case .high: return .orange
                case .medium: return .yellow
                case .low: return .blue
                }
            }

            static func < (lhs: Priority, rhs: Priority) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }

        enum Action: Codable {
            case restartApp(name: String)
            case closeBrowserTabs
            case restartMac
            case reduceStartupItems
            case clearDownloads
            case stopDocker
            case closeXcode
            case reduceSafariTabs
            case cleanTimeMachine
            case cleanIOSUpdates
            case cleanNodeModules
            case cleanIOSBackups
            case cleanLargeFiles
            case cleanMessages
            case deepScan
            case noAction
        }
        
        enum Category: String {
            case memory = "Memory"
            case storage = "Storage"
            case performance = "Performance"
            case developer = "Developer"
            case security = "Security"
        }

        enum Color {
            case red, orange, yellow, blue, green
        }
    }

    struct MemorySnapshot {
        var totalAppsRunning: Int
        var memoryPressure: MemoryPressureLevel
        var swapUsedGB: Double
        var topMemoryApps: [(name: String, memMB: Double)]
        var browserTabCounts: [String: Int]
        var daysSinceRestart: Int
        var hasHighMemoryApps: Bool
        var dockerRunning: Bool
        var dockerDiskUsageMB: Int64
    }

    private var processMonitor = ProcessMemoryMonitor.shared
    private var systemMonitor = SystemMemoryMonitor.shared
    private let workQueue = DispatchQueue(label: "com.memorymonitor.suggestions", qos: .utility)

    private init() {}

    // MARK: - Analyze and Generate Suggestions

    func analyze() {
        guard !isAnalyzing else { return }
        isAnalyzing = true
        
        print("[SmartSuggestions] Starting analysis...")
        
        // Run all heavy work on background queue
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            var newSuggestions: [Suggestion] = []
            var totalGB: Double = 0

            let snapshot = self.gatherMemorySnapshot()

            // MARK: - Storage Suggestions (High Impact)
            
            // Time Machine Snapshots
            let tmSize = TimeMachineManager.estimateRecoverableGB()
            print("[SmartSuggestions] Time Machine: \(tmSize)GB")
            if tmSize > 5 {
                totalGB += tmSize
                newSuggestions.append(Suggestion(
                    title: "Time Machine snapshots: \(String(format: "%.0f GB", tmSize))",
                    detail: "Local snapshots can be safely deleted. iCloud/external backups remain intact.",
                    icon: "clock.arrow.circlepath",
                    action: .cleanTimeMachine,
                    priority: tmSize > 50 ? .critical : .high,
                    potentialSavings: String(format: "%.0f GB", tmSize),
                    category: .storage
                ))
            }
            
            // iOS Updates
            let storage = StorageAnalyzer.shared
            let iosUpdatesGB = storage.totalIOSUpdatesGB > 0 ? storage.totalIOSUpdatesGB : self.quickScanIOSUpdates()
            print("[SmartSuggestions] iOS Updates: \(iosUpdatesGB)GB")
            if iosUpdatesGB > 1 {
                totalGB += iosUpdatesGB
                newSuggestions.append(Suggestion(
                    title: "iOS updates: \(String(format: "%.0f GB", iosUpdatesGB))",
                    detail: "Old iOS/macOS update files can be deleted. Apple re-downloads if needed.",
                    icon: "iphone",
                    action: .cleanIOSUpdates,
                    priority: .high,
                    potentialSavings: String(format: "%.0f GB", iosUpdatesGB),
                    category: .storage
                ))
            }
            
            // iOS Backups
            let iosBackupsGB = self.quickScanIOSBackups()
            print("[SmartSuggestions] iOS Backups: \(iosBackupsGB)GB")
            if iosBackupsGB > 5 {
                totalGB += iosBackupsGB
                newSuggestions.append(Suggestion(
                    title: "iOS backups: \(String(format: "%.0f GB", iosBackupsGB))",
                    detail: "Old device backups can be removed. Check Settings to see backup dates.",
                    icon: "externaldrive.fill",
                    action: .cleanIOSBackups,
                    priority: .medium,
                    potentialSavings: String(format: "%.0f GB", iosBackupsGB),
                    category: .storage
                ))
            }
            
            // node_modules
            let nodeModulesGB = self.quickScanNodeModules()
            print("[SmartSuggestions] node_modules: \(nodeModulesGB)GB")
            if nodeModulesGB > 0.5 { // Lower threshold to 500MB
                totalGB += nodeModulesGB
                newSuggestions.append(Suggestion(
                    title: "node_modules: \(String(format: "%.1f GB", nodeModulesGB))",
                    detail: "Node.js dependency folders can be cleaned. Run 'npm install' to restore.",
                    icon: "cube.box.fill",
                    action: .cleanNodeModules,
                    priority: .medium,
                    potentialSavings: String(format: "%.1f GB", nodeModulesGB),
                    category: .developer
                ))
            }
            
            // Downloads folder
            let downloadsSize = self.getDownloadsSize()
            let downloadsGB = Double(downloadsSize) / 1024.0
            print("[SmartSuggestions] Downloads: \(downloadsGB)GB")
            if downloadsGB > 0.5 { // 500MB
                totalGB += downloadsGB
                newSuggestions.append(Suggestion(
                    title: "Downloads: \(String(format: "%.1f GB", downloadsGB))",
                    detail: "Your Downloads folder has old files that could be cleaned up.",
                    icon: "arrow.down.circle.fill",
                    action: .clearDownloads,
                    priority: .low,
                    potentialSavings: String(format: "%.1f GB", downloadsGB),
                    category: .storage
                ))
            }
            
            print("[SmartSuggestions] Total recoverable: \(totalGB)GB")

            // MARK: - Memory Suggestions

            // Critical: Memory pressure is critical
            if snapshot.memoryPressure == .critical {
                newSuggestions.append(Suggestion(
                    title: "Memory Pressure Critical",
                    detail: "Your Mac is under severe memory pressure. Consider closing some apps.",
                    icon: "exclamationmark.octagon.fill",
                    action: .noAction,
                    priority: .critical,
                    potentialSavings: "Varies",
                    category: .memory
                ))
            }

            // High: Too many apps running
            if snapshot.totalAppsRunning > 15 {
                newSuggestions.append(Suggestion(
                    title: "\(snapshot.totalAppsRunning) apps running",
                    detail: "You have many apps open. Close unused ones to free memory.",
                    icon: "app.badge.fill",
                    action: .noAction,
                    priority: .high,
                    potentialSavings: "100-500 MB",
                    category: .memory
                ))
            }

            // High: Safari tabs
            if let tabCount = snapshot.browserTabCounts["Safari"], tabCount > 20 {
                newSuggestions.append(Suggestion(
                    title: "\(tabCount) Safari tabs open",
                    detail: "Safari tabs can use 50-200MB each. Consider bookmarking and closing some.",
                    icon: "safari.fill",
                    action: .reduceSafariTabs,
                    priority: tabCount > 50 ? .high : .medium,
                    potentialSavings: "\(min(tabCount * 50, 2000)) MB",
                    category: .memory
                ))
            }

            // High: Chrome tabs
            if let tabCount = snapshot.browserTabCounts["Chrome"], tabCount > 20 {
                newSuggestions.append(Suggestion(
                    title: "\(tabCount) Chrome tabs open",
                    detail: "Chrome uses more memory per tab than Safari. Consider using tabs more efficiently.",
                    icon: "globe",
                    action: .reduceSafariTabs,
                    priority: tabCount > 50 ? .high : .medium,
                    potentialSavings: "\(min(tabCount * 80, 4000)) MB",
                    category: .memory
                ))
            }

            // High: Idle Docker with actual disk usage
            if self.isDockerRunning() && !self.isDockerBusy() {
                let dockerSizeMB = self.getDockerDiskUsageMB()
                if dockerSizeMB > 100 { // Only suggest if > 100MB
                    newSuggestions.append(Suggestion(
                        title: "Docker idle with \(self.formatBytes(dockerSizeMB)) reclaimable",
                        detail: "Docker is running but not in use. Clean up to free disk space.",
                        icon: "cube.box.fill",
                        action: .stopDocker,
                        priority: .medium,
                        potentialSavings: self.formatBytes(dockerSizeMB),
                        category: .developer
                    ))
                }
            }

            // High: High memory apps
            for app in snapshot.topMemoryApps.prefix(3) {
                if app.memMB > 1000 {
                    newSuggestions.append(Suggestion(
                        title: "\(app.name) using \(Int(app.memMB)) MB",
                        detail: "This app is using significant memory. Consider restarting it.",
                        icon: "memorychip",
                        action: .restartApp(name: app.name),
                        priority: .medium,
                        potentialSavings: "\(Int(app.memMB * 0.7)) MB",
                        category: .memory
                    ))
                }
            }

            // MARK: - Performance Suggestions

            // Medium: Not restarted in a while
            if snapshot.daysSinceRestart > 7 {
                newSuggestions.append(Suggestion(
                    title: "Restart recommended",
                    detail: "Your Mac hasn't been restarted in \(snapshot.daysSinceRestart) days. A restart clears memory leaks.",
                    icon: "arrow.clockwise",
                    action: .restartMac,
                    priority: .medium,
                    potentialSavings: "500MB - 2GB",
                    category: .performance
                ))
            }

            // Medium: High swap usage
            if snapshot.swapUsedGB > 5 {
                newSuggestions.append(Suggestion(
                    title: "High swap usage: \(String(format: "%.1f GB", snapshot.swapUsedGB))",
                    detail: "Your Mac is using disk as memory. Close apps or restart to clear swap.",
                    icon: "internaldrive.fill",
                    action: .restartMac,
                    priority: .high,
                    potentialSavings: "1-4 GB",
                    category: .performance
                ))
            }

            // MARK: - Deep Scan Suggestion
            
            if totalGB > 10 {
                newSuggestions.append(Suggestion(
                    title: "\(String(format: "%.0f GB", totalGB)) recoverable",
                    detail: "Run a deep scan to find and clean all recoverable items.",
                    icon: "sparkles",
                    action: .deepScan,
                    priority: .low,
                    potentialSavings: String(format: "%.0f GB", totalGB),
                    category: .storage
                ))
            }

            // Sort by priority
            newSuggestions.sort { $0.priority < $1.priority }

            // Keep top 8 suggestions
            DispatchQueue.main.async {
                self.suggestions = Array(newSuggestions.prefix(8))
                self.totalRecoverableGB = totalGB
                self.lastUpdated = Date()
                self.isAnalyzing = false
            }
        }
    }
    
    // MARK: - Quick Scans for Storage
    
    private func quickScanIOSUpdates() -> Double {
        let iosUpdatesPath = NSString(string: "~/Library/iTunes/iOS Updates").expandingTildeInPath
        var total: Double = 0
        
        if let files = try? FileManager.default.contentsOfDirectory(atPath: iosUpdatesPath) {
            for file in files {
                let filePath = iosUpdatesPath + "/" + file
                if let attrs = try? FileManager.default.attributesOfItem(atPath: filePath),
                   let size = attrs[.size] as? Int64 {
                    total += Double(size) / (1024 * 1024 * 1024)
                }
            }
        }
        
        return total
    }
    
    private func quickScanIOSBackups() -> Double {
        let backupPath = NSString(string: "~/Library/Application Support/MobileSync/Backup").expandingTildeInPath
        var total: Double = 0
        
        if let dirs = try? FileManager.default.contentsOfDirectory(atPath: backupPath) {
            for dir in dirs {
                let dirPath = backupPath + "/" + dir
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: dirPath, isDirectory: &isDir), isDir.boolValue {
                    // Use du for quick size
                    let task = Process()
                    task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
                    task.arguments = ["-sk", dirPath]
                    let pipe = Pipe()
                    task.standardOutput = pipe
                    task.standardError = Pipe()
                    try? task.run()
                    task.waitUntilExit()
                    
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8),
                       let kb = output.split(separator: "\t").first.flatMap({ Double($0) }) {
                        total += kb / (1024 * 1024) // KB to GB
                    }
                }
            }
        }
        
        return total
    }
    
    private func quickScanNodeModules() -> Double {
        let home = FileManager.default.homeDirectoryForCurrentUser
        var total: Double = 0
        var folderCount = 0
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/find")
        task.arguments = [home.path, "-name", "node_modules", "-type", "d", "-maxdepth", "5"]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            let paths = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            folderCount = paths.count
            
            // Get ACTUAL sizes using du (more accurate)
            for path in paths.prefix(10) { // Limit to 10 for performance
                let duTask = Process()
                duTask.executableURL = URL(fileURLWithPath: "/usr/bin/du")
                duTask.arguments = ["-sk", path]
                let duPipe = Pipe()
                duTask.standardOutput = duPipe
                duTask.standardError = Pipe()
                
                try? duTask.run()
                duTask.waitUntilExit()
                
                let duData = duPipe.fileHandleForReading.readDataToEndOfFile()
                if let duOutput = String(data: duData, encoding: .utf8),
                   let kb = duOutput.split(separator: "\t").first.flatMap({ Double($0) }) {
                    total += kb / (1024 * 1024) // KB to GB
                }
            }
            
            print("[SmartSuggestions] Found \(folderCount) node_modules folders, actual total: \(total)GB")
            
        } catch {
            print("[SmartSuggestions] Error scanning node_modules: \(error)")
        }
        
        return total
    }

    // MARK: - Helper Methods

    private func gatherMemorySnapshot() -> MemorySnapshot {
        // Check Docker status once
        let dockerIsRunning = isDockerRunning()
        
        var snapshot = MemorySnapshot(
            totalAppsRunning: 0,
            memoryPressure: systemMonitor.pressureLevel,
            swapUsedGB: systemMonitor.currentMemory?.swapUsedGB ?? 0,
            topMemoryApps: [],
            browserTabCounts: [:],
            daysSinceRestart: getDaysSinceRestart(),
            hasHighMemoryApps: false,
            dockerRunning: dockerIsRunning,
            dockerDiskUsageMB: dockerIsRunning ? getDockerDiskUsageMB() : 0
        )

        // Count running apps
        let runningApps = NSWorkspace.shared.runningApplications
        snapshot.totalAppsRunning = runningApps.filter { $0.activationPolicy == .regular }.count

        // Get top memory apps
        let topProcesses = processMonitor.topProcesses
        snapshot.topMemoryApps = topProcesses.map { ($0.name, $0.memoryMB) }
        snapshot.hasHighMemoryApps = topProcesses.contains { $0.memoryMB > 1000 }

        // Estimate browser tabs (via running processes)
        snapshot.browserTabCounts["Safari"] = countSafariTabs()
        snapshot.browserTabCounts["Chrome"] = countChromeTabs()

        return snapshot
    }

    private func countSafariTabs() -> Int {
        // Use AppleScript for accurate Safari tab count
        let script = """
        tell application "Safari"
            if it is running then
                set totalTabs to 0
                repeat with w in windows
                    set totalTabs to totalTabs + (count of tabs of w)
                end repeat
                return totalTabs
            else
                return 0
            end if
        end tell
        """
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let count = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                return count
            }
        } catch {
            print("[SmartSuggestions] Error counting Safari tabs: \(error)")
        }
        
        return 0
    }

    private func countChromeTabs() -> Int {
        // Chrome doesn't support AppleScript well, use process count as estimate
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Count Chrome renderer processes (more accurate indicator)
        let lines = output.components(separatedBy: "\n")
        let rendererCount = lines.filter { 
            $0.contains("Google Chrome") && $0.contains("--type=renderer") 
        }.count
        
        // Each tab typically has 1 renderer
        return rendererCount
    }

    private func isDockerRunning() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", "docker"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    private func isDockerBusy() -> Bool {
        // Check if Docker is actively building or running containers
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["ps"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
        return lines.count > 1 // More than just header
    }

    private func getDockerDiskUsageMB() -> Int64 {
        // Get Docker disk usage using docker system df
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["system", "df", "--format", "{{.Size}}"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Parse output like "1.234GB", "567MB"
        var totalMB: Int64 = 0
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }
            
            // Parse size strings like "1.5GB" or "500MB"
            if let value = Double(trimmed.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)) {
                if trimmed.uppercased().contains("GB") {
                    totalMB += Int64(value * 1024)
                } else if trimmed.uppercased().contains("MB") {
                    totalMB += Int64(value)
                } else if trimmed.uppercased().contains("KB") {
                    totalMB += Int64(value / 1024)
                } else if trimmed.uppercased().contains("B") {
                    totalMB += Int64(value / (1024 * 1024))
                }
            }
        }
        return totalMB
    }

    private func getDaysSinceRestart() -> Int {
        // Use system uptime as proxy
        var boottime = timeval()
        var size = MemoryLayout<timeval>.size
        var mib: [Int32] = [CTL_KERN, KERN_BOOTTIME]
        
        if sysctl(&mib, 2, &boottime, &size, nil, 0) != -1 {
            let now = Date().timeIntervalSince1970
            let boot = Double(boottime.tv_sec)
            let uptime = now - boot
            return Int(uptime / 86400) // Days
        }
        return 1
    }

    private func getDownloadsSize() -> Int64 {
        let downloads = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        let sizeMB = DirectorySizeUtility.directorySizeMB(downloads.path)
        return Int64(sizeMB)
    }

    private func formatBytes(_ mb: Int64) -> String {
        let gb = Double(mb) / 1024
        if gb > 1 {
            return String(format: "%.1f GB", gb)
        }
        return "\(mb) MB"
    }
}
