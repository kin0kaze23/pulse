import Foundation
import AppKit
import UserNotifications
import Darwin

/// Security & Privacy Scanner with File-Based Persistence Detection
/// Note: This is NOT real-time threat monitoring - it's a file watcher for persistence mechanisms
/// 
/// Features:
/// - Launch Agents/Daemons scanner (like KnockKnock)
/// - Suspicious process name detection (heuristic, NOT definitive keylogger detection)
/// - Login items scanner (incomplete on macOS Sonoma+)
/// - Browser extension scanner
/// - Cron job scanner
/// - File watchers for persistence locations (detects changes, doesn't prevent them)
/// 
/// Limitations:
/// - Cannot detect kernel-level threats (requires Endpoint Security framework)
/// - Cannot definitively detect keyloggers (heuristic only)
/// - Cannot block malicious actions (only alerts after the fact)
/// - Login items scan incomplete on macOS Sonoma+
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

    // Security Status Checks (Phase 1: Foundation Hardening)
    @Published var fileVaultEnabled: Bool = false
    @Published var fileVaultStatus: String = "Checking..."
    @Published var gatekeeperEnabled: Bool = false
    @Published var gatekeeperStatus: String = "Checking..."
    
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
        let isUnnecessary: Bool
        let unnecessaryReason: String?
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
    ]

    private let suspiciousKeywords = [
        "keylog", "logger", "monitor", "track", "spy", "steal",
        "capture", "record", "inject", "hook", "intercept",
        "remote", "backdoor", "trojan", "rat", "keysniff",
        "screencapture", "screen_capture", "mousehook"
    ]

    // MARK: - Internal Accessors for Testing

    /// Check if a bundle ID is in the known-safe whitelist.
    /// Internal visibility for test access.
    func isKnownSafeBundleID(_ bundleID: String) -> Bool {
        knownSafeBundleIDs.contains { bundleID.hasPrefix($0) }
    }

    /// Check if a process name contains suspicious keywords.
    /// Internal visibility for test access.
    func containsSuspiciousKeyword(_ name: String) -> Bool {
        let lower = name.lowercased()
        return suspiciousKeywords.contains { lower.contains($0) }
    }

    // Known unnecessary third-party daemons - not malware but consume resources
    // These are update checkers, telemetry agents, or leftover installers
    private let knownUnnecessaryDaemonPrefixes = [
        "com.adobe.ARMDC",              // Adobe update checker
        "com.adobe.AdobeGCClient",      // Adobe Genuine Client
        "com.oracle.java",              // Oracle Java updater
        "com.macpaw",                   // CleanMyMac agent
        "com.google.GoogleUpdater",     // Google software updater
        "com.google.Keystone",          // Google Keystone updater
        "com.microsoft.update",         // Microsoft auto-update
        "com.teamviewer.",              // TeamViewer (if not actively used)
        "com.anydesk.",                 // AnyDesk (if not actively used)
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

                // Refresh security status checks (FileVault, Gatekeeper)
                self.refreshSecurityStatus()

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
            let (isUnnecessary, unnecessaryReason) = checkUnnecessaryDaemon(label: label)

            let item = PersistenceItem(
                name: label,
                path: fullPath,
                type: type,
                bundleID: label,
                executablePath: program,
                isApple: isApple,
                isSuspicious: isSuspicious.0,
                suspicionReason: isSuspicious.1,
                isUnnecessary: isUnnecessary,
                unnecessaryReason: unnecessaryReason,
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
                let (isUnnecessary, unnecessaryReason) = checkUnnecessaryDaemon(label: bundleID)

                let item = PersistenceItem(
                    name: file.replacingOccurrences(of: ".app", with: ""),
                    path: fullPath,
                    type: .loginItem,
                    bundleID: bundleID,
                    executablePath: fullPath,
                    isApple: isApple,
                    isSuspicious: isSuspicious.0,
                    suspicionReason: isSuspicious.1,
                    isUnnecessary: isUnnecessary,
                    unnecessaryReason: unnecessaryReason,
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

    /// Check for potential keylogger activity
    /// Note: This is a heuristic check - macOS doesn't expose which apps have accessibility access
    /// without Full Disk Access. We check for suspicious process names and behaviors.
    private func checkForKeyloggers() -> KeyloggerRisk {
        var suspiciousApps = 0

        // Use NSWorkspace to get running apps
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }

            // Skip Apple apps
            if bundleID.hasPrefix("com.apple.") { continue }

            // Skip known safe apps
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
        }

        // Check if Full Disk Access is available (for informational purposes only)
        // We no longer attempt to read TCC.db directly as it violates macOS security
        let hasFDA = checkFullDiskAccess()
        DispatchQueue.main.async {
            self.hasTCCAccess = hasFDA
        }

        // Risk assessment based on suspicious apps found
        // Note: Without FDA, we cannot definitively detect keyloggers
        if suspiciousApps > 0 {
            return .high  // Suspicious named app found
        }

        // If no suspicious apps but FDA is missing, warn user about limited detection
        if !hasFDA {
            return .low  // Limited visibility - user should grant FDA for better protection
        }

        return .none
    }

    /// Check if Pulse has Full Disk Access permission
    /// Returns true if we can read protected directories
    private func checkFullDiskAccess() -> Bool {
        // Try to read a protected file to check FDA status
        let testPath = "/Library/Application Support/com.apple.TCC"
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    /// Open System Settings to grant Full Disk Access
    func requestFullDiskAccess() {
        // Open System Settings → Privacy & Security → Full Disk Access
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        } else {
            // Fallback for macOS Sonoma and later
            if let url = URL(string: "x-apple.systempreferences:com.apple.PrivacySettings") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    /// Open System Settings to grant Accessibility permission
    func requestAccessibilityPermission() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Check if Pulse itself has Accessibility permission
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Request Accessibility permission
    func requestAccessibility() {
        // This triggers the system prompt if not already granted
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
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

    /// Check if a daemon/agent is known unnecessary bloat (update checkers, telemetry, leftover installers)
    /// These are not malware but consume resources and can be safely removed
    private func checkUnnecessaryDaemon(label: String) -> (Bool, String?) {
        for prefix in knownUnnecessaryDaemonPrefixes {
            if label.hasPrefix(prefix) {
                let reason = unnecessaryReasonForPrefix(prefix, label: label)
                return (true, reason)
            }
        }
        return (false, nil)
    }

    private func unnecessaryReasonForPrefix(_ prefix: String, label: String) -> String {
        switch prefix {
        case "com.adobe.ARMDC":
            return "Adobe update checker - remove if not using Adobe CC"
        case "com.adobe.AdobeGCClient":
            return "Adobe Genuine Client telemetry - remove if not using Adobe CC"
        case "com.oracle.java":
            return "Oracle Java updater - remove if not using Java"
        case "com.macpaw":
            return "CleanMyMac agent - redundant if using Pulse"
        case "com.google.GoogleUpdater":
            return "Google software updater - runs in background daily"
        case "com.google.Keystone":
            return "Google Keystone updater - runs in background daily"
        case "com.microsoft.update":
            return "Microsoft auto-update - runs in background periodically"
        case "com.teamviewer.":
            return "TeamViewer daemon - remove if not actively using remote access"
        case "com.anydesk.":
            return "AnyDesk daemon - remove if not actively using remote access"
        default:
            return "Known unnecessary third-party daemon"
        }
    }

    private func analyzeItems(_ items: [PersistenceItem]) -> [SecurityWarning] {
        var warnings: [SecurityWarning] = []

        // Warn about suspicious items
        for item in items where item.isSuspicious {
            warnings.append(SecurityWarning(
                severity: item.isApple ? .low : .high,
                title: "Suspicious \(item.type.rawValue)",
                detail: "\(item.name): \(item.suspicionReason ?? "Unknown")",
                recommendation: item.canDisable ? "Consider disabling" : "Review this item",
                itemPath: item.path
            ))
        }

        // Warn about unnecessary third-party daemons (bloat, not malware)
        let unnecessaryItems = items.filter { $0.isUnnecessary }
        for item in unnecessaryItems {
            warnings.append(SecurityWarning(
                severity: .medium,
                title: "Unnecessary Daemon",
                detail: "\(item.name): \(item.unnecessaryReason ?? "Known unnecessary")",
                recommendation: "Remove to free resources and reduce background activity",
                itemPath: item.path
            ))
        }

        // Warn if there are many unnecessary daemons in aggregate
        if unnecessaryItems.count >= 3 {
            let estimatedRAM = Double(unnecessaryItems.count) * 30.0
            warnings.append(SecurityWarning(
                severity: .medium,
                title: "\(unnecessaryItems.count) Unnecessary Daemons Detected",
                detail: "These consume ~\(Int(estimatedRAM)) MB RAM combined and run in background",
                recommendation: "Review and remove unused software to improve performance",
                itemPath: nil
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

    // MARK: - Security Status Checks (Phase 1: Foundation Hardening)

    /// Check FileVault disk encryption status using fdesetup
    func checkFileVaultStatus() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/fdesetup")
            task.arguments = ["isactive"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                // Exit code 0 = FileVault is active, 1 = not active
                let isEnabled = task.terminationStatus == 0

                DispatchQueue.main.async {
                    self.fileVaultEnabled = isEnabled
                    self.fileVaultStatus = isEnabled ? "Enabled" : "Not Enabled"
                }
            } catch {
                DispatchQueue.main.async {
                    self.fileVaultEnabled = false
                    self.fileVaultStatus = "Unable to check"
                }
            }
        }
    }

    /// Check Gatekeeper app verification status using spctl
    func checkGatekeeperStatus() {
        workQueue.async { [weak self] in
            guard let self = self else { return }

            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
            task.arguments = ["--status"]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = Pipe()

            do {
                try task.run()
                task.waitUntilExit()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

                let isEnabled = output == "assess enabled"

                DispatchQueue.main.async {
                    self.gatekeeperEnabled = isEnabled
                    self.gatekeeperStatus = isEnabled ? "Enabled" : "Disabled"
                }
            } catch {
                DispatchQueue.main.async {
                    self.gatekeeperEnabled = false
                    self.gatekeeperStatus = "Unable to check"
                }
            }
        }
    }

    /// Refresh all security status checks
    func refreshSecurityStatus() {
        checkFileVaultStatus()
        checkGatekeeperStatus()
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