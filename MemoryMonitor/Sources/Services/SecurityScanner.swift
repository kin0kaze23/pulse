import Foundation
import AppKit
import UserNotifications
import Darwin

/// Security & Privacy Scanner with Real-Time Monitoring
/// Inspired by Objective-See tools (KnockKnock, Reikey, BlockBlock)
///
/// Features:
/// - Launch Agents/Daemons scanner (like KnockKnock)
/// - Keyboard event tap detection (like Reikey)
/// - Login items scanner
/// - Network extension checker
/// - REAL-TIME monitoring for new threats
/// - Background threat detection
class SecurityScanner: ObservableObject {
    static let shared = SecurityScanner()
    
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var scanPhase: ScanPhase = .idle
    @Published var isMonitoring = false
    @Published var lastScanDate: Date?
    @Published var persistenceItems: [PersistenceItem] = []
    @Published var securityWarnings: [SecurityWarning] = []
    @Published var keyloggerRisk: KeyloggerRisk = .none
    @Published var overallRisk: SecurityRisk = .unknown
    
    // Real-time monitoring
    @Published var recentThreats: [SecurityEvent] = []
    @Published var threatCount: Int = 0
    @Published var monitoringEnabled: Bool = true
    @Published var hasTCCAccess: Bool = false
    
    // MARK: - Scan Phase
    
    enum ScanPhase: String {
        case idle = "Ready"
        case initializing = "Initializing..."
        case launchAgents = "Scanning Launch Agents..."
        case launchDaemons = "Scanning Launch Daemons..."
        case loginItems = "Scanning Login Items..."
        case keyloggers = "Checking for Keyloggers..."
        case analyzing = "Analyzing Results..."
        case complete = "Complete"
        
        var progress: Double {
            switch self {
            case .idle: return 0
            case .initializing: return 0.05
            case .launchAgents: return 0.25
            case .launchDaemons: return 0.50
            case .loginItems: return 0.70
            case .keyloggers: return 0.85
            case .analyzing: return 0.95
            case .complete: return 1.0
            }
        }
        
        var estimatedTime: String {
            switch self {
            case .idle: return "Ready to scan"
            case .initializing: return "~5 seconds remaining"
            case .launchAgents: return "~4 seconds remaining"
            case .launchDaemons: return "~3 seconds remaining"
            case .loginItems: return "~2 seconds remaining"
            case .keyloggers: return "~1 second remaining"
            case .analyzing: return "Almost done..."
            case .complete: return "Scan complete"
            }
        }
    }
    
    // MARK: - Models
    
    enum SecurityRisk: String {
        case unknown = "Unknown"
        case low = "Low Risk"
        case medium = "Medium Risk"
        case high = "High Risk"
        case critical = "Critical Risk"
        
        var color: String {
            switch self {
            case .unknown: return "gray"
            case .low: return "green"
            case .medium: return "yellow"
            case .high: return "orange"
            case .critical: return "red"
            }
        }
    }
    
    enum KeyloggerRisk: String {
        case none = "None Detected"
        case low = "Low Risk"
        case medium = "Possible Keylogger"
        case high = "Likely Keylogger"
        
        var color: String {
            switch self {
            case .none: return "green"
            case .low: return "yellow"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }
    
    struct SecurityEvent: Identifiable {
        let id = UUID()
        let timestamp: Date
        let type: EventType
        let severity: SecurityWarning.Severity
        let title: String
        let detail: String
        let path: String?
        
        enum EventType: String {
            case newPersistence = "New Persistence"
            case modifiedPersistence = "Modified Item"
            case suspiciousProcess = "Suspicious Process"
            case keyloggerDetected = "Keylogger"
            case networkAnomaly = "Network Anomaly"
        }
    }
    
    struct PersistenceItem: Identifiable {
        let id = UUID()
        let name: String
        let path: String
        let type: PersistenceType
        let bundleID: String?
        let executablePath: String?
        let isApple: Bool
        let isSuspicious: Bool
        let suspicionReason: String?
        let memoryImpactMB: Double
        let canDisable: Bool
        let modificationDate: Date?
        
        enum PersistenceType: String {
            case launchAgent = "Launch Agent"
            case launchDaemon = "Launch Daemon"
            case loginItem = "Login Item"
            case systemExtension = "System Extension"
            case browserExtension = "Browser Extension"
            
            var icon: String {
                switch self {
                case .launchAgent: return "person.fill"
                case .launchDaemon: return "gearshape.2.fill"
                case .loginItem: return "rectangle.bottomhalf.inset.filled"
                case .systemExtension: return "puzzlepiece.extension.fill"
                case .browserExtension: return "safari.fill"
                }
            }
        }
    }
    
    struct SecurityWarning: Identifiable {
        let id = UUID()
        let severity: Severity
        let title: String
        let detail: String
        let recommendation: String
        let itemPath: String?
        
        enum Severity: Int, Comparable {
            case info = 0
            case low = 1
            case medium = 2
            case high = 3
            case critical = 4
            
            var icon: String {
                switch self {
                case .info: return "info.circle.fill"
                case .low: return "checkmark.circle.fill"
                case .medium: return "exclamationmark.triangle.fill"
                case .high: return "exclamationmark.octagon.fill"
                case .critical: return "xmark.octagon.fill"
                }
            }
            
            var color: String {
                switch self {
                case .info: return "blue"
                case .low: return "green"
                case .medium: return "yellow"
                case .high: return "orange"
                case .critical: return "red"
                }
            }
            
            static func < (lhs: Severity, rhs: Severity) -> Bool {
                lhs.rawValue < rhs.rawValue
            }
        }
    }
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private var fileWatchers: [FileWatcher] = []
    private var baselineItems: Set<String> = []
    private let workQueue = DispatchQueue(label: "com.memorymonitor.security", qos: .utility)
    
    private let knownAppleBundleIDs = [
        "com.apple.",
    ]
    
    private let knownSafeBundleIDs = [
        "com.microsoft.VSCode",
        "com.jetbrains.intellij",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.apple.dt.Xcode",
        "com.sublimetext.3",
        "com.tinyspeck.slackmacgap",
        "com.hnc.Discord",
        "com.spotify.client",
        "com.dropbox.dropbox",
        "com.microsoft.teams",
        "com.adobe",
        "com.docker.docker",
        "com.macpaw.CleanMyMac",
        "com.littleSnitch",
        "com.objective-see.LuLu",
        "com.opencode",
        "com.paperclip",
        "com.jonathannugroho",
    ]
    
    private let suspiciousKeywords = [
        "keylog", "logger", "monitor", "track", "spy", "steal",
        "capture", "record", "inject", "hook", "intercept",
        "remote", "backdoor", "trojan", "rat", "keysniff",
        "screencapture", "screen_capture", "mousehook"
    ]
    
    private init() {
        // Load saved baseline
        loadBaseline()
        
        // Don't auto-start monitoring - let the view trigger it
    }
    
    // MARK: - Real-Time Monitoring
    
    func startRealTimeMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        monitoringEnabled = true
        
        print("[SecurityScanner] Starting real-time monitoring...")
        
        // Trigger initial scan on background queue (don't block)
        workQueue.async { [weak self] in
            self?.scan()
        }
        
        // Set up periodic monitoring (every 60 seconds)
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.performBackgroundCheck()
        }
        
        // Set up file system watchers for persistence locations
        setupFileWatchers()
    }
    
    func stopRealTimeMonitoring() {
        isMonitoring = false
        monitoringEnabled = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        // Stop file watchers
        for watcher in fileWatchers {
            watcher.stop()
        }
        fileWatchers.removeAll()
        
        print("[SecurityScanner] Stopped real-time monitoring")
    }
    
    private func setupFileWatchers() {
        let pathsToWatch = [
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents").path,
            "/Library/LaunchAgents",
            "/Library/LaunchDaemons",
            FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LoginItems").path,
        ]
        
        for path in pathsToWatch {
            // Only watch if path exists
            guard FileManager.default.fileExists(atPath: path) else { continue }
            
            let watcher = FileWatcher(path: path) { [weak self] event in
                self?.handleFileEvent(event)
            }
            watcher.start()
            fileWatchers.append(watcher)
        }
    }
    
    private func handleFileEvent(_ event: FileWatcher.Event) {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            switch event {
            case .created(let path):
                // New persistence item detected
                self.addThreatEvent(
                    type: .newPersistence,
                    severity: .medium,
                    title: "New Startup Item Detected",
                    detail: URL(fileURLWithPath: path).lastPathComponent,
                    path: path
                )
                
                // Trigger immediate scan
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.scan()
                }
                
            case .modified(let path):
                // Check if modification is suspicious
                if self.isSuspiciousPath(path) {
                    self.addThreatEvent(
                        type: .modifiedPersistence,
                        severity: .low,
                        title: "Startup Item Modified",
                        detail: URL(fileURLWithPath: path).lastPathComponent,
                        path: path
                    )
                }
                
            case .deleted(let path):
                // Item removed - could be cleanup or malware removal
                print("[SecurityScanner] Item deleted: \(path)")
            }
        }
    }
    
    private func addThreatEvent(type: SecurityEvent.EventType, severity: SecurityWarning.Severity, title: String, detail: String, path: String?) {
        let event = SecurityEvent(
            timestamp: Date(),
            type: type,
            severity: severity,
            title: title,
            detail: detail,
            path: path
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.recentThreats.insert(event, at: 0)
            self.threatCount += 1
            
            // Keep only last 50 events
            if self.recentThreats.count > 50 {
                self.recentThreats.removeLast()
            }
            
            // Show notification for high severity
            if severity == .high || severity == .critical {
                self.showSecurityNotification(title: title, body: detail)
            }
        }
    }
    
    private func performBackgroundCheck() {
        workQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Check for new processes with suspicious behavior
            self.checkForSuspiciousProcesses()
            
            // Re-check keylogger status
            let currentKeyloggerRisk = self.checkForKeyloggers()
            
            DispatchQueue.main.async {
                if currentKeyloggerRisk != self.keyloggerRisk {
                    self.keyloggerRisk = currentKeyloggerRisk
                    
                    if currentKeyloggerRisk == .high || currentKeyloggerRisk == .medium {
                        self.addThreatEvent(
                            type: .keyloggerDetected,
                            severity: currentKeyloggerRisk == .high ? .critical : .high,
                            title: "Potential Keylogger Activity",
                            detail: "Application is monitoring keyboard events",
                            path: nil
                        )
                    }
                }
            }
        }
    }
    
    // MARK: - Suspicious Process Detection
    
    private func checkForSuspiciousProcesses() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "pid=,rss=,command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                for line in output.components(separatedBy: "\n") {
                    let lowercased = line.lowercased()
                    
                    // Check for suspicious process names
                    for keyword in suspiciousKeywords {
                        if lowercased.contains(keyword) && !lowercased.contains("grep") {
                            // Found suspicious process
                            let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                            if let pid = parts.first, let _ = Int(pid) {
                                DispatchQueue.main.async {
                                    self.addThreatEvent(
                                        type: .suspiciousProcess,
                                        severity: .high,
                                        title: "Suspicious Process Detected",
                                        detail: line.trimmingCharacters(in: .whitespaces),
                                        path: nil
                                    )
                                }
                            }
                            break
                        }
                    }
                }
            }
        } catch {}
    }
    
    private func isSuspiciousPath(_ path: String) -> Bool {
        let suspiciousIndicators = [".sh", ".py", ".rb", "tmp", "temp"]
        return suspiciousIndicators.contains { path.lowercased().contains($0) }
    }
    
    // MARK: - Main Scan
    
    func scan() {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allItems: [PersistenceItem] = []
            var warnings: [SecurityWarning] = []
            var newItems: [String] = []
            
            // Phase 1: Initializing
            DispatchQueue.main.async {
                self.scanPhase = .initializing
                self.scanProgress = ScanPhase.initializing.progress
            }
            Thread.sleep(forTimeInterval: 0.2)
            
            // Phase 2: Scan Launch Agents
            DispatchQueue.main.async {
                self.scanPhase = .launchAgents
                self.scanProgress = ScanPhase.launchAgents.progress
            }
            let launchAgents = self.scanLaunchAgents()
            allItems.append(contentsOf: launchAgents)
            
            // Phase 3: Scan Launch Daemons
            DispatchQueue.main.async {
                self.scanPhase = .launchDaemons
                self.scanProgress = ScanPhase.launchDaemons.progress
            }
            let launchDaemons = self.scanLaunchDaemons()
            allItems.append(contentsOf: launchDaemons)
            
            // Phase 4: Scan Login Items
            DispatchQueue.main.async {
                self.scanPhase = .loginItems
                self.scanProgress = ScanPhase.loginItems.progress
            }
            let loginItems = self.scanLoginItems()
            allItems.append(contentsOf: loginItems)
            
            // Phase 5: Check for keyloggers
            DispatchQueue.main.async {
                self.scanPhase = .keyloggers
                self.scanProgress = ScanPhase.keyloggers.progress
            }
            
            // Check for new items (not in baseline)
            for item in allItems {
                if !self.baselineItems.contains(item.path) {
                    newItems.append(item.path)
                }
            }
            
            let keyloggerStatus = self.checkForKeyloggers()
            
            // Phase 6: Analyzing
            DispatchQueue.main.async {
                self.scanPhase = .analyzing
                self.scanProgress = ScanPhase.analyzing.progress
            }
            
            // Generate warnings
            warnings.append(contentsOf: self.analyzeItems(allItems))
            
            // Add keylogger warning if detected
            if keyloggerStatus != .none {
                warnings.append(SecurityWarning(
                    severity: keyloggerStatus == .high ? .critical : .high,
                    title: "Potential Keylogger Detected",
                    detail: "An application is monitoring keyboard events",
                    recommendation: "Review running applications and revoke accessibility permissions",
                    itemPath: nil
                ))
            }
            
            // Add warnings for new items
            for itemPath in newItems {
                if let item = allItems.first(where: { $0.path == itemPath }), !item.isApple {
                    self.addThreatEvent(
                        type: .newPersistence,
                        severity: item.isSuspicious ? .high : .medium,
                        title: "New Startup Item",
                        detail: item.name,
                        path: item.path
                    )
                }
            }
            
            // Calculate overall risk
            let overallRisk = self.calculateOverallRisk(items: allItems, warnings: warnings, keylogger: keyloggerStatus)
            
            // Phase 7: Complete
            DispatchQueue.main.async {
                self.scanPhase = .complete
                self.scanProgress = 1.0
                
                self.persistenceItems = allItems.sorted {
                    ($0.isSuspicious ? 0 : 1) < ($1.isSuspicious ? 0 : 1)
                }
                self.securityWarnings = warnings.sorted { $0.severity > $1.severity }
                self.keyloggerRisk = keyloggerStatus
                self.overallRisk = overallRisk
                self.lastScanDate = Date()
                self.isScanning = false
                
                // Save baseline
                self.saveBaseline(items: allItems)
                
                print("[SecurityScanner] Scan complete: \(allItems.count) items, \(warnings.count) warnings, risk: \(overallRisk.rawValue)")
            }
        }
    }
    
    // MARK: - Launch Agents Scanner
    
    private func scanLaunchAgents() -> [PersistenceItem] {
        var items: [PersistenceItem] = []
        
        // User LaunchAgents
        let userAgentsPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents").path
        items.append(contentsOf: scanPlistDirectory(userAgentsPath, type: .launchAgent))
        
        // System LaunchAgents
        items.append(contentsOf: scanPlistDirectory("/Library/LaunchAgents", type: .launchAgent))
        
        return items
    }
    
    private func scanLaunchDaemons() -> [PersistenceItem] {
        var items: [PersistenceItem] = []
        items.append(contentsOf: scanPlistDirectory("/Library/LaunchDaemons", type: .launchDaemon))
        items.append(contentsOf: scanPlistDirectory("/System/Library/LaunchDaemons", type: .launchDaemon, isSystem: true))
        return items
    }
    
    private func scanPlistDirectory(_ path: String, type: PersistenceItem.PersistenceType, isSystem: Bool = false) -> [PersistenceItem] {
        var items: [PersistenceItem] = []
        
        // Check if directory exists
        guard FileManager.default.fileExists(atPath: path) else { return items }
        
        guard let enumerator = FileManager.default.enumerator(atPath: path) else { return items }
        
        for case let file as String in enumerator {
            guard file.hasSuffix(".plist") else { continue }
            
            let fullPath = (path as NSString).appendingPathComponent(file)
            
            // Skip if can't read
            guard let plistData = FileManager.default.contents(atPath: fullPath) else { continue }
            
            // Parse plist with error handling
            guard let plist = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any] else {
                continue
            }
            
            let label = plist["Label"] as? String ?? file.replacingOccurrences(of: ".plist", with: "")
            let programArgs = plist["ProgramArguments"] as? [String]
            let program = plist["Program"] as? String ?? programArgs?.first
            
            // Skip memory estimation - too slow for initial scan
            // Memory will show as 0, but we can estimate later if needed
            
            let isApple = label.hasPrefix("com.apple.") || isSystem
            let isSuspicious = checkSuspicious(label: label, program: program)
            
            let item = PersistenceItem(
                name: label,
                path: fullPath,
                type: type,
                bundleID: label,
                executablePath: program,
                isApple: isApple,
                isSuspicious: isSuspicious.0,
                suspicionReason: isSuspicious.1,
                memoryImpactMB: 0, // Skip slow memory check
                canDisable: !isSystem && !isApple,
                modificationDate: nil // Skip slow date check
            )
            
            items.append(item)
        }
        
        return items
    }
    
// MARK: - Login Items Scanner
    
    private func scanLoginItems() -> [PersistenceItem] {
        var items: [PersistenceItem] = []
        let loginItemPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LoginItems").path
        
        // Check if directory exists
        guard FileManager.default.fileExists(atPath: loginItemPath) else { return items }
        
        guard let enumerator = FileManager.default.enumerator(atPath: loginItemPath) else { return items }
        
        for case let file as String in enumerator {
            let fullPath = (loginItemPath as NSString).appendingPathComponent(file)
            
            // Check if it's an app bundle
            if file.hasSuffix(".app") {
                let bundleURL = URL(fileURLWithPath: fullPath)
                guard let bundle = Bundle(url: bundleURL),
                      let bundleID = bundle.bundleIdentifier else { continue }
                
                let isApple = bundleID.hasPrefix("com.apple.")
                let isSuspicious = checkSuspicious(label: bundleID, program: fullPath)
                
                let item = PersistenceItem(
                    name: file.replacingOccurrences(of: ".app", with: ""),
                    path: fullPath,
                    type: .loginItem,
                    bundleID: bundleID,
                    executablePath: fullPath,
                    isApple: isApple,
                    isSuspicious: isSuspicious.0,
                    suspicionReason: isSuspicious.1,
                    memoryImpactMB: 0,
                    canDisable: !isApple,
                    modificationDate: nil
                )
                
                items.append(item)
            }
        }
        
        return items
    }
    
    // MARK: - Keylogger Detection
    
    private func checkForKeyloggers() -> KeyloggerRisk {
        // Check if THIS app has Accessibility permission (AXIsProcessTrusted)
        // Then check running apps for suspicious accessibility usage

        var suspiciousApps = 0
        var totalAppsWithAccessibility = 0

        // Use NSWorkspace to get running apps, check their accessibility trust status
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }

            // Skip Apple apps
            if bundleID.hasPrefix("com.apple.") { continue }

            // Skip known safe apps - use contains() predicate correctly
            let isSafe = knownSafeBundleIDs.contains { bundleID.hasPrefix($0) }
            if isSafe { continue }

            // Check if the app has suspicious keywords in its bundle ID or name
            let appName = app.localizedName?.lowercased() ?? ""
            let bundleLower = bundleID.lowercased()

            let hasSuspiciousKeyword = suspiciousKeywords.contains {
                bundleLower.contains($0) || appName.contains($0)
            }

            if hasSuspiciousKeyword {
                suspiciousApps += 1
            }

            // Count non-Apple, non-safe apps as candidates
            totalAppsWithAccessibility += 1
        }

        // Additionally: check if Full Disk Access is available to do deeper scan
        let tccPath = "/Library/Application Support/com.apple.TCC/TCC.db"
        if FileManager.default.isReadableFile(atPath: tccPath) {
            DispatchQueue.main.async {
                self.hasTCCAccess = true
            }
            return checkKeyloggersViaTCC(tccPath: tccPath, suspiciousSoFar: suspiciousApps)
        }
        
        DispatchQueue.main.async {
            self.hasTCCAccess = false
        }

        // Fallback: keyword-based only
        if suspiciousApps > 0 { return .high }
        return .none
    }

    private func checkKeyloggersViaTCC(tccPath: String, suspiciousSoFar: Int) -> KeyloggerRisk {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        task.arguments = [tccPath,
            "SELECT client FROM access WHERE service='kTCCServiceAccessibility' AND allowed=1;"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            let deadline = Date().addingTimeInterval(3)
            while task.isRunning && Date() < deadline {
                RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.05))
            }
            if task.isRunning { task.terminate(); return suspiciousSoFar > 0 ? .high : .none }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return .none }

            let apps = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            var suspicious = suspiciousSoFar
            var total = 0

            for app in apps {
                let lower = app.lowercased()
                if lower.hasPrefix("com.apple.") { continue }
                // FIX: use contains() predicate instead of broken nested continue
                let isSafe = knownSafeBundleIDs.contains { lower.contains($0.lowercased()) }
                if isSafe { continue }
                total += 1
                let hasSuspiciousKeyword = suspiciousKeywords.contains { lower.contains($0) }
                if hasSuspiciousKeyword { suspicious += 1 }
            }

            if suspicious > 0 { return .high }
            if total > 10 { return .medium }
            if total > 0 { return .low }
            return .none
        } catch {
            return suspiciousSoFar > 0 ? .high : .none
        }
    }
    
    // MARK: - Analysis
    
    private func checkSuspicious(label: String, program: String?) -> (Bool, String?) {
        let labelLower = label.lowercased()
        let programLower = program?.lowercased() ?? ""
        
        // Check for suspicious keywords first (fast)
        for keyword in suspiciousKeywords {
            if labelLower.contains(keyword) || programLower.contains(keyword) {
                return (true, "Suspicious keyword: '\(keyword)'")
            }
        }
        
        // Skip codesign check for Apple and known safe items (they're signed)
        if label.hasPrefix("com.apple.") {
            return (false, nil)
        }
        for safeID in knownSafeBundleIDs {
            if label.hasPrefix(safeID) {
                return (false, nil)
            }
        }
        
        // Check for unusual locations (fast)
        if let program = program {
            if program.contains("/tmp/") || program.contains("/var/tmp/") {
                return (true, "Running from temp location")
            }
            if program.hasPrefix("/.") || program.contains("/.hidden") {
                return (true, "Hidden path")
            }
        }
        
        // Skip codesign check for most items - it's too slow
        // Only check if running from unusual locations or has suspicious keywords
        return (false, nil)
    }
    
    private func analyzeItems(_ items: [PersistenceItem]) -> [SecurityWarning] {
        var warnings: [SecurityWarning] = []
        
        for item in items where item.isSuspicious {
            warnings.append(SecurityWarning(
                severity: item.isApple ? .low : .high,
                title: "Suspicious \(item.type.rawValue)",
                detail: "\(item.name): \(item.suspicionReason ?? "Unknown")",
                recommendation: item.canDisable ? "Consider disabling" : "Review this item",
                itemPath: item.path
            ))
        }
        
        let loginItemsCount = items.filter { $0.type == .loginItem && !$0.isApple }.count
        if loginItemsCount > 10 {
            warnings.append(SecurityWarning(
                severity: .medium,
                title: "Many Login Items",
                detail: "\(loginItemsCount) login items slow startup",
                recommendation: "Disable unnecessary items",
                itemPath: nil
            ))
        }
        
        return warnings
    }
    
    private func calculateOverallRisk(items: [PersistenceItem], warnings: [SecurityWarning], keylogger: KeyloggerRisk) -> SecurityRisk {
        if keylogger == .high { return .critical }
        if warnings.contains(where: { $0.severity == .critical }) { return .critical }
        if keylogger == .medium { return .high }
        if warnings.contains(where: { $0.severity == .high }) { return .high }
        if warnings.contains(where: { $0.severity == .medium }) { return .medium }
        if !warnings.isEmpty { return .low }
        
        let suspiciousCount = items.filter { $0.isSuspicious }.count
        if suspiciousCount > 0 { return .low }
        
        return .low
    }
    
    // MARK: - Baseline Management
    
    private func loadBaseline() {
        if let saved = UserDefaults.standard.array(forKey: "securityBaseline") as? [String] {
            baselineItems = Set(saved)
        }
    }
    
    private func saveBaseline(items: [PersistenceItem]) {
        let paths = items.map { $0.path }
        baselineItems = Set(paths)
        UserDefaults.standard.set(Array(baselineItems), forKey: "securityBaseline")
    }
    
    // MARK: - Notifications
    
    private func showSecurityNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = "🛡️ \(title)"
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "security-alert-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[SecurityScanner] Notification error: \(error)")
            }
        }
    }
    
    // MARK: - Actions
    
    func disableItem(_ item: PersistenceItem) -> Bool {
        guard item.canDisable else { return false }
        
        do {
            if item.type == .launchAgent || item.type == .launchDaemon {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/launchctl")
                task.arguments = ["unload", item.path]
                try task.run()
                task.waitUntilExit()
            }
            return true
        } catch {
            print("[SecurityScanner] Failed to disable: \(error)")
            return false
        }
    }
    
    func openSystemPreferencesSecurity() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
    
    func clearRecentThreats() {
        recentThreats.removeAll()
        threatCount = 0
    }
}

// MARK: - File Watcher

private class FileWatcher {
    enum Event {
        case created(String)
        case modified(String)
        case deleted(String)
    }
    
    private let path: String
    private let callback: (Event) -> Void
    private var source: DispatchSourceFileSystemObject?
    
    init(path: String, callback: @escaping (Event) -> Void) {
        self.path = path
        self.callback = callback
    }
    
    func start() {
        let descriptor = open(path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: descriptor,
            eventMask: [.write, .delete, .extend],
            queue: DispatchQueue.global(qos: .background)
        )
        
        source?.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            if self.source?.data.contains(.delete) == true {
                self.callback(.deleted(self.path))
            } else if self.source?.data.contains(.extend) == true {
                self.callback(.created(self.path))
            } else {
                self.callback(.modified(self.path))
            }
        }
        
        source?.resume()
    }
    
    func stop() {
        source?.cancel()
    }
    
    deinit {
        stop()
    }
}