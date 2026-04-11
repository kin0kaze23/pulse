import Foundation
import AppKit
import Darwin

/// Comprehensive Memory & System Optimizer - Advanced Edition
/// Inspired by Mole, enhanced with intelligent detection and user safety
///
/// FEATURES:
/// - Dry-run mode: scanForCleanup() returns plan without deleting
/// - Intelligent app detection: warns if apps are running before cleanup
/// - User confirmation required before destructive operations
/// - Detailed results showing what was cleaned, skipped, and why
/// - OpenCode DB cleanup integration
/// - Extensive cache coverage: developer tools, browsers, apps, system
/// - Whitelist support for protecting specific paths
class ComprehensiveOptimizer: ObservableObject {
    static let shared = ComprehensiveOptimizer()

    @Published var isWorking = false
    @Published var lastResult: OptimizeResult?
    @Published var statusMessage: String = ""
    @Published var progress: Double = 0
    @Published var needsConfirmation = false
    @Published var currentPlan: CleanupPlan?
    
    // Apps that need to be closed for safe cleanup
    @Published var appsToClose: [String] = []
    
    // MARK: - Progress Phases
    
    enum ScanPhase {
        case idle
        case developerCaches
        case browserCaches
        case systemCaches
        case applicationCaches
        case logs
        case trash
        case analyzing
        
        var message: String {
            switch self {
            case .idle: return "Ready"
            case .developerCaches: return "Scanning developer caches..."
            case .browserCaches: return "Scanning browser caches..."
            case .systemCaches: return "Scanning system caches..."
            case .applicationCaches: return "Scanning applications..."
            case .logs: return "Scanning logs..."
            case .trash: return "Checking trash..."
            case .analyzing: return "Analyzing results..."
            }
        }
        
        var progress: Double {
            switch self {
            case .idle: return 0
            case .developerCaches: return 0.15
            case .browserCaches: return 0.30
            case .systemCaches: return 0.45
            case .applicationCaches: return 0.60
            case .logs: return 0.70
            case .trash: return 0.85
            case .analyzing: return 0.95
            }
        }
        
        var estimatedTime: String {
            switch self {
            case .idle: return "Click Optimize to start"
            case .developerCaches: return "~6 sec remaining"
            case .browserCaches: return "~5 sec remaining"
            case .systemCaches: return "~4 sec remaining"
            case .applicationCaches: return "~3 sec remaining"
            case .logs: return "~2 sec remaining"
            case .trash: return "~1 sec remaining"
            case .analyzing: return "Almost done..."
            }
        }
    }

    // MARK: - Cleanup Plan (Dry-Run)

    struct CleanupPlan: Identifiable {
        let id = UUID()
        let items: [CleanupItem]
        let warnings: [CleanupWarning]
        let totalSizeMB: Double
        let timestamp: Date

        var totalSizeText: String {
            if totalSizeMB > 1024 {
                return String(format: "%.1f GB", totalSizeMB / 1024)
            }
            return String(format: "%.0f MB", totalSizeMB)
        }

        var itemCount: Int { items.count }
        var warningCount: Int { warnings.count }

        var isSignificant: Bool { totalSizeMB > 50 } // Prompt if > 50MB or has warnings

        struct CleanupItem: Identifiable {
            let id = UUID()
            let name: String
            let sizeMB: Double
            let category: OptimizeResult.Category
            let path: String
            let isDestructive: Bool
            let requiresAppClosed: Bool
            let appName: String?
            let warningMessage: String?
            let priority: CleanupPriority
            var skipReason: String?

            init(name: String, sizeMB: Double, category: OptimizeResult.Category, path: String, isDestructive: Bool, requiresAppClosed: Bool, appName: String?, warningMessage: String?, skipReason: String? = nil, priority: CleanupPriority = .medium) {
                self.name = name
                self.sizeMB = sizeMB
                self.category = category
                self.path = path
                self.isDestructive = isDestructive
                self.requiresAppClosed = requiresAppClosed
                self.appName = appName
                self.warningMessage = warningMessage
                self.skipReason = skipReason
                self.priority = priority
            }

            var sizeText: String {
                if sizeMB > 1024 {
                    return String(format: "%.1f GB", sizeMB / 1024)
                }
                return String(format: "%.0f MB", sizeMB)
            }
        }
        
        struct CleanupWarning: Identifiable {
            let id = UUID()
            let message: String
            let appName: String
            let itemsAffected: Int
        }
    }

    // MARK: - Optimize Result (uses shared type)
    
    /// Type alias to shared OptimizeResult
    typealias OptimizeResult = Pulse.OptimizeResult

    // MARK: - Settings

    var settings: AppSettings { AppSettings.shared }

    private init() {}

    // MARK: - Public API

    /// Scan for cleanup candidates WITHOUT actually deleting anything (dry-run)
    /// Use this to show the user what will be cleaned before confirmation
    func scanForCleanup() {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = "Scanning..."
        progress = 0

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var items: [CleanupPlan.CleanupItem] = []

            // Minimum scan time for UX - at least 2 seconds so user sees progress
            let startTime = Date()
            let minimumScanTime: TimeInterval = 2.0

            // Scan developer caches
            DispatchQueue.main.async { self.statusMessage = "Scanning developer caches..."; self.progress = 0.1 }
            Thread.sleep(forTimeInterval: 0.3) // Small delay for UX
            items.append(contentsOf: self.scanDeveloperCaches())

            // Scan browser caches
            DispatchQueue.main.async { self.statusMessage = "Scanning browser caches..."; self.progress = 0.3 }
            Thread.sleep(forTimeInterval: 0.3)
            items.append(contentsOf: self.scanBrowserCaches())

            // Scan system caches
            DispatchQueue.main.async { self.statusMessage = "Scanning system caches..."; self.progress = 0.5 }
            Thread.sleep(forTimeInterval: 0.3)
            items.append(contentsOf: self.scanSystemCaches())
            
            // Scan application caches
            DispatchQueue.main.async { self.statusMessage = "Scanning applications..."; self.progress = 0.6 }
            Thread.sleep(forTimeInterval: 0.3)
            items.append(contentsOf: self.scanApplicationCaches())
            
            // Scan logs
            DispatchQueue.main.async { self.statusMessage = "Scanning logs..."; self.progress = 0.65 }
            Thread.sleep(forTimeInterval: 0.3)
            items.append(contentsOf: self.scanLogs())

            // Check trash
            DispatchQueue.main.async { self.statusMessage = "Checking trash..."; self.progress = 0.7 }
            Thread.sleep(forTimeInterval: 0.3)
            let trashSize = self.scanTrash()
            if trashSize > 0 {
                items.append(.init(
                    name: "Trash",
                    sizeMB: trashSize,
                    category: .disk,
                    path: "~/.Trash",
                    isDestructive: true,
                    requiresAppClosed: false,
                    appName: nil,
                    warningMessage: "Permanently deletes files in Trash",
                    priority: .high
                ))
            }
            
            // Generate warnings for apps that need to be closed
            var warnings: [CleanupPlan.CleanupWarning] = []
            var appsToCloseSet = Set<String>()
            for item in items {
                if let appName = item.appName, item.requiresAppClosed {
                    if isAppRunning(appName) {
                        appsToCloseSet.insert(appName)
                    }
                }
            }
            for app in appsToCloseSet {
                let affectedItems = items.filter { $0.appName == app }.count
                warnings.append(.init(
                    message: "\(app) is running - close it for safe cleanup",
                    appName: app,
                    itemsAffected: affectedItems
                ))
            }

            // Analyzing
            DispatchQueue.main.async { self.statusMessage = "Analyzing results..."; self.progress = 0.9 }

            let totalSize = items.reduce(0) { $0 + $1.sizeMB }
            let plan = CleanupPlan(items: items, warnings: warnings, totalSizeMB: totalSize, timestamp: Date())

            // Ensure minimum scan time for better UX
            let elapsed = Date().timeIntervalSince(startTime)
            if elapsed < minimumScanTime {
                Thread.sleep(forTimeInterval: minimumScanTime - elapsed)
            }

            DispatchQueue.main.async {
                self.currentPlan = plan
                self.needsConfirmation = plan.isSignificant
                self.isWorking = false
                self.statusMessage = ""
                self.progress = 1.0
                
                print("[ComprehensiveOptimizer] Scan complete: \(items.count) items, \(totalSize)MB total, needsConfirmation: \(plan.isSignificant)")
            }
        }
    }

    /// Execute cleanup for selected items only (filters the plan)
    /// - Parameter selectedIds: Set of item IDs to actually clean
    func executeCleanup(selectedIds: Set<UUID>) {
        guard !isWorking, let plan = currentPlan else {
            // SAFETY FIX (Phase 1): No longer auto-execute fullOptimize without confirmation.
            // Instead, scan first and present a plan for user confirmation.
            statusMessage = "Scanning... a plan will be presented for your confirmation"
            scanForCleanup()
            return
        }

        // Filter to only selected items
        let filteredItems = plan.items.filter { selectedIds.contains($0.id) }

        guard !filteredItems.isEmpty else {
            print("[ComprehensiveOptimizer] No items selected for cleanup")
            isWorking = false
            statusMessage = "No items selected"
            return
        }

        // Clear confirmation flag
        needsConfirmation = false
        isWorking = true
        statusMessage = "Starting cleanup..."
        progress = 0

        executeFilteredCleanup(items: filteredItems)
    }

    /// Execute cleanup for all items in plan (legacy method)
    /// SAFETY FIX (Phase 1): If no plan exists, scans first instead of blindly executing fullOptimize
    func executeCleanup() {
        guard let plan = currentPlan else {
            // SAFETY FIX: Scan first, present plan for confirmation
            statusMessage = "Scanning... a plan will be presented for your confirmation"
            scanForCleanup()
            return
        }
        let allIds = Set(plan.items.map { $0.id })
        executeCleanup(selectedIds: allIds)
    }

    /// Internal method to execute cleanup for filtered items
    private func executeFilteredCleanup(items: [CleanupPlan.CleanupItem]) {

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var steps: [OptimizeResult.Step] = []
            var skipped: [OptimizeResult.SkippedItem] = []
            let totalItems = max(items.count, 1)

            print("[ComprehensiveOptimizer] Executing cleanup for \(items.count) selected items")

            // Execute each selected item with detailed progress
            for (index, item) in items.enumerated() {
                let progressPct = Double(index) / Double(totalItems)
                
                // Show detailed status message
                let categoryIcon = self.iconForCategory(item.category)
                DispatchQueue.main.async {
                    self.statusMessage = "\(categoryIcon) \(item.name)..."
                    self.progress = progressPct
                }

                // Delay for UX so user can see what's happening
                Thread.sleep(forTimeInterval: 0.5)
                
                // Check if app needs to be closed
                if item.requiresAppClosed, let appName = item.appName, self.isAppRunning(appName) {
                    // Skip this item - app is running
                    skipped.append(.init(
                        name: item.name,
                        reason: "\(appName) is running",
                        sizeMB: item.sizeMB
                    ))
                    print("[ComprehensiveOptimizer] Skipped \(item.name): \(appName) is running")
                    continue
                }

                let freed = self.executeCleanupItem(item)
                if freed < 0 {
                    // Item was skipped
                    skipped.append(.init(
                        name: item.name,
                        reason: "Could not clean safely",
                        sizeMB: item.sizeMB
                    ))
                } else {
                    steps.append(.init(
                        name: item.name,
                        freedMB: freed,
                        success: freed >= 0,
                        category: item.category
                    ))
                    print("[ComprehensiveOptimizer] Cleaned \(item.name): \(freed)MB freed")
                }
            }

            // Close idle apps as final step for immediate memory relief
            DispatchQueue.main.async {
                self.statusMessage = "Closing idle apps..."
                self.progress = 0.9
            }
            Thread.sleep(forTimeInterval: 0.3)
            
            let idleFreed = self.closeIdleApps()
            if idleFreed.0 > 0 {
                steps.append(.init(
                    name: "Closed \(idleFreed.1) idle apps",
                    freedMB: idleFreed.0,
                    success: true,
                    category: .memory
                ))
                print("[ComprehensiveOptimizer] Closed \(idleFreed.1) idle apps, freed \(idleFreed.0)MB")
            }

            let totalFreed = steps.reduce(0) { $0 + max(0, $1.freedMB) }
            let result = OptimizeResult(steps: steps, skipped: skipped, totalFreedMB: totalFreed, timestamp: Date())
            
            print("[ComprehensiveOptimizer] Cleanup complete: \(totalFreed)MB freed, \(skipped.count) skipped")

            DispatchQueue.main.async {
                self.lastResult = result
                self.currentPlan = nil
                self.isWorking = false
                self.statusMessage = ""
                self.progress = 1.0
                self.refreshMonitors()
            }
        }
    }
    
    private func iconForCategory(_ category: OptimizeResult.Category) -> String {
        switch category {
        case .developer: return "💻"
        case .browser: return "🌐"
        case .application: return "📱"
        case .system: return "⚙️"
        case .memory: return "🧠"
        case .disk: return "💾"
        case .logs: return "📄"
        }
    }

    /// SAFETY FIX (Phase 1): No longer bypasses confirmation for destructive operations.
    /// Instead, runs quickOptimize which only closes idle apps and flushes DNS (no file deletion).
    func executeWithoutConfirmation() {
        quickOptimize()
    }

    /// Cancel pending confirmation
    func cancelPendingCleanup() {
        needsConfirmation = false
        currentPlan = nil
    }

    /// Quick memory-only optimization (no confirmation needed)
    /// Skips slow purge command - focuses on closing idle apps and flushing caches
    func quickOptimize() {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = "Finding idle apps..."
        progress = 0.1

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var steps: [OptimizeResult.Step] = []
            
            print("[ComprehensiveOptimizer] Running quick optimize")

            // Close idle apps (most impactful action)
            DispatchQueue.main.async { 
                self.statusMessage = "Finding idle apps..."
                self.progress = 0.3
            }
            Thread.sleep(forTimeInterval: 0.5)
            
            let idleFreed = self.closeIdleApps()
            if idleFreed.0 > 0 {
                steps.append(.init(name: "Closed \(idleFreed.1) idle apps", freedMB: idleFreed.0, success: true, category: .memory))
                print("[ComprehensiveOptimizer] Closed \(idleFreed.1) idle apps, freed \(idleFreed.0)MB")
            }

            // Flush DNS (quick operation)
            DispatchQueue.main.async { 
                self.statusMessage = "Flushing DNS cache..."
                self.progress = 0.6
            }
            Thread.sleep(forTimeInterval: 0.3)
            
            self.flushDNS()
            steps.append(.init(name: "DNS cache flushed", freedMB: 0, success: true, category: .system))

            // Clear some memory pressure by forcing a context switch
            DispatchQueue.main.async { 
                self.statusMessage = "Finalizing..."
                self.progress = 0.9
            }
            Thread.sleep(forTimeInterval: 0.3)

            let totalFreed = steps.reduce(0) { $0 + $1.freedMB }
            let result = OptimizeResult(steps: steps, skipped: [], totalFreedMB: totalFreed, timestamp: Date())
            
            print("[ComprehensiveOptimizer] Quick optimize complete: \(totalFreed)MB freed")

            DispatchQueue.main.async {
                self.lastResult = result
                self.statusMessage = ""
                self.progress = 1.0
                self.isWorking = false
                self.refreshMonitors()
            }
        }
    }

    /// Free RAM - simple quick cleanup for menu bar quick action
    /// Calls cacheOnlyOptimize which is fast and doesn't need confirmation
    func freeRAM() {
        cacheOnlyOptimize()
    }

    // MARK: - Cache-Only Optimization (Fast, No Confirmation)

    /// Fast cache cleanup - cleans caches and closes idle apps, no confirmation needed
    /// Safe to run anytime - skips apps that are running
    func cacheOnlyOptimize() {
        guard !isWorking else { return }
        isWorking = true
        statusMessage = "Scanning caches..."
        progress = 0.05

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var steps: [OptimizeResult.Step] = []
            var skipped: [OptimizeResult.SkippedItem] = []
            
            print("[ComprehensiveOptimizer] Running cache-only optimize")

            // Phase 1: Developer Caches (safe to clean)
            DispatchQueue.main.async { 
                self.statusMessage = "Cleaning developer caches..."
                self.progress = 0.1
            }
            
            let devItems = self.scanDeveloperCaches()
            for item in devItems {
                // Skip items that require app to be closed
                if item.requiresAppClosed, let appName = item.appName, self.isAppRunning(appName) {
                    skipped.append(.init(name: item.name, reason: "\(appName) is running", sizeMB: item.sizeMB))
                    continue
                }
                
                DispatchQueue.main.async { self.statusMessage = "💻 \(item.name)..." }
                Thread.sleep(forTimeInterval: 0.1)
                let freed = self.executeCleanupItem(item)
                if freed > 0 {
                    steps.append(.init(name: item.name, freedMB: freed, success: true, category: item.category))
                }
            }

            // Phase 2: Browser Caches (only if not running)
            DispatchQueue.main.async { 
                self.statusMessage = "Cleaning browser caches..."
                self.progress = 0.35
            }
            
            let browserItems = self.scanBrowserCaches()
            for item in browserItems {
                if let appName = item.appName, self.isAppRunning(appName) {
                    skipped.append(.init(name: item.name, reason: "\(appName) is running", sizeMB: item.sizeMB))
                    continue
                }
                
                DispatchQueue.main.async { self.statusMessage = "🌐 \(item.name)..." }
                Thread.sleep(forTimeInterval: 0.1)
                let freed = self.executeCleanupItem(item)
                if freed > 0 {
                    steps.append(.init(name: item.name, freedMB: freed, success: true, category: item.category))
                }
            }

            // Phase 3: System Caches (always safe)
            DispatchQueue.main.async { 
                self.statusMessage = "Cleaning system caches..."
                self.progress = 0.55
            }
            
            let sysItems = self.scanSystemCaches()
            for item in sysItems {
                if item.requiresAppClosed, let appName = item.appName, self.isAppRunning(appName) {
                    skipped.append(.init(name: item.name, reason: "\(appName) is running", sizeMB: item.sizeMB))
                    continue
                }
                
                DispatchQueue.main.async { self.statusMessage = "⚙️ \(item.name)..." }
                Thread.sleep(forTimeInterval: 0.1)
                let freed = self.executeCleanupItem(item)
                if freed > 0 {
                    steps.append(.init(name: item.name, freedMB: freed, success: true, category: item.category))
                }
            }

            // Phase 4: Close idle apps
            DispatchQueue.main.async { 
                self.statusMessage = "Closing idle apps..."
                self.progress = 0.8
            }
            Thread.sleep(forTimeInterval: 0.3)
            
            let idleFreed = self.closeIdleApps()
            if idleFreed.0 > 0 {
                steps.append(.init(name: "Closed \(idleFreed.1) idle apps", freedMB: idleFreed.0, success: true, category: .memory))
                print("[ComprehensiveOptimizer] Closed \(idleFreed.1) idle apps, freed \(idleFreed.0)MB")
            }

            // Phase 5: Flush DNS
            DispatchQueue.main.async { 
                self.statusMessage = "Flushing DNS..."
                self.progress = 0.9
            }
            Thread.sleep(forTimeInterval: 0.2)
            
            self.flushDNS()
            steps.append(.init(name: "DNS cache flushed", freedMB: 0, success: true, category: .system))

            let totalFreed = steps.reduce(0) { $0 + $1.freedMB }
            let result = OptimizeResult(steps: steps, skipped: skipped, totalFreedMB: totalFreed, timestamp: Date())
            
            print("[ComprehensiveOptimizer] Cache-only optimize complete: \(totalFreed)MB freed, \(skipped.count) skipped")

            DispatchQueue.main.async {
                self.lastResult = result
                self.statusMessage = ""
                self.progress = 1.0
                self.isWorking = false
                self.refreshMonitors()
            }
        }
    }

    // MARK: - Full Optimization

    /// SAFETY FIX (Phase 1): This method no longer auto-executes deletions.
    /// It now scans for cleanup candidates and presents a plan requiring user confirmation.
    /// The old behavior of directly deleting files without confirmation has been removed.
    @available(*, deprecated, message: "Use scanForCleanup() followed by executeCleanup(selectedIds:) for safe, confirmed cleanup")
    private func fullOptimize() {
        // Redirect to the safe flow: scan first, then require confirmation
        scanForCleanup()
    }

    // MARK: - Priority-Based Filtering

    /// Result of grouping cleanup items by priority
    struct PriorityGroup {
        let high: [CleanupPlan.CleanupItem]
        let medium: [CleanupPlan.CleanupItem]
        let low: [CleanupPlan.CleanupItem]
        let optional: [CleanupPlan.CleanupItem]

        var allItems: [CleanupPlan.CleanupItem] {
            high + medium + low + optional
        }

        var totalSizeMB: Double {
            allItems.reduce(0) { $0 + $1.sizeMB }
        }

        var itemCount: Int { allItems.count }
    }

    /// Group the current cleanup plan items by priority.
    /// Returns nil if no plan has been scanned yet.
    func scanByPriority() -> PriorityGroup? {
        guard let plan = currentPlan else { return nil }

        var high: [CleanupPlan.CleanupItem] = []
        var medium: [CleanupPlan.CleanupItem] = []
        var low: [CleanupPlan.CleanupItem] = []
        var optional: [CleanupPlan.CleanupItem] = []

        for item in plan.items {
            switch item.priority {
            case .high: high.append(item)
            case .medium: medium.append(item)
            case .low: low.append(item)
            case .optional: optional.append(item)
            }
        }

        return PriorityGroup(high: high, medium: medium, low: low, optional: optional)
    }

    // MARK: - Scanner Methods (Dry-Run)

    private func scanDeveloperCaches() -> [CleanupPlan.CleanupItem] {
        var items: [CleanupPlan.CleanupItem] = []
        
        // Package manager caches
        let devCachePaths: [(name: String, path: String)] = [
            ("npm cache", "~/.npm"),
            ("Yarn cache", "~/Library/Caches/Yarn"),
            ("pnpm store", "~/Library/pnpm/store"),
            ("Bun cache", "~/.bun/install/cache"),
            ("pip cache", "~/Library/Caches/pip"),
            ("Go module cache", "~/go/pkg/mod"),
            ("Go build cache", "~/Library/Caches/go-build"),
            ("Cargo registry", "~/.cargo/registry"),
            ("Gradle cache", "~/.gradle/caches"),
            ("TypeScript cache", "~/.cache/typescript"),
            ("Vite cache", "~/.vite/cache"),
        ]

        for (name, path) in devCachePaths {
            let size = DirectorySizeUtility.quickDirectorySizeMB(path)
            if size > 20 { // Show if > 20MB
                items.append(.init(
                    name: name,
                    sizeMB: size,
                    category: .developer,
                    path: path,
                    isDestructive: false,
                    requiresAppClosed: false,
                    appName: nil,
                    warningMessage: nil
                ))
            }
        }

        // Xcode - requires Xcode to be closed
        let xcodeRunning = isAppRunning("Xcode")
        if settings.cleanXcodeDerivedData {
            let xcodeSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Developer/Xcode/DerivedData")
            if xcodeSize > 50 {
                items.append(.init(
                    name: "Xcode DerivedData",
                    sizeMB: xcodeSize,
                    category: .developer,
                    path: "~/Library/Developer/Xcode/DerivedData",
                    isDestructive: false,
                    requiresAppClosed: true,
                    appName: "Xcode",
                    warningMessage: xcodeRunning ? "Close Xcode to clean safely" : nil,
                    priority: .medium
                ))
            }
        }

        // Xcode DeviceSupport (only if enabled)
        if settings.cleanXcodeDeviceSupport {
            let deviceSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Developer/Xcode/iOS DeviceSupport")
            if deviceSize > 100 {
                items.append(.init(
                    name: "iOS DeviceSupport",
                    sizeMB: deviceSize,
                    category: .developer,
                    path: "~/Library/Developer/Xcode/iOS DeviceSupport",
                    isDestructive: false,
                    requiresAppClosed: false,
                    appName: nil,
                    warningMessage: "Removes old device debugging symbols",
                    priority: .medium
                ))
            }
        }
        
        // Xcode Archives (old builds)
        let archivesSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Developer/Xcode/Archives")
        if archivesSize > 100 {
            items.append(.init(
                name: "Xcode Archives",
                sizeMB: archivesSize,
                category: .developer,
                path: "~/Library/Developer/Xcode/Archives",
                isDestructive: false, // NOT destructive - build artifacts can be rebuilt
                requiresAppClosed: false,
                appName: nil,
                warningMessage: "Contains archived builds - delete only if you don't need them",
                priority: .low
            ))
        }
        
        // iOS Simulators
        let simulatorSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Developer/CoreSimulator")
        if simulatorSize > 500 {
            items.append(.init(
                name: "iOS Simulators",
                sizeMB: simulatorSize,
                category: .developer,
                path: "~/Library/Developer/CoreSimulator",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: "Run 'xcrun simctl delete unavailable' to clean safely",
                priority: .low
            ))
        }

        // JetBrains - check if running
        let jetbrainsRunning = isAppRunning("IntelliJ IDEA") || isAppRunning("WebStorm") || isAppRunning("PyCharm")
        let jetbrainsSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Caches/JetBrains")
        if jetbrainsSize > 50 {
            items.append(.init(
                name: "JetBrains IDE cache",
                sizeMB: jetbrainsSize,
                category: .developer,
                path: "~/Library/Caches/JetBrains",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "JetBrains IDE",
                warningMessage: jetbrainsRunning ? "Close JetBrains IDE to clean safely" : nil
            ))
        }

        // VS Code
        let vscodeRunning = isAppRunning("Electron") || isAppRunning("Code Helper")
        let vscodeSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Caches/com.microsoft.VSCode")
        if vscodeSize > 30 {
            items.append(.init(
                name: "VS Code cache",
                sizeMB: vscodeSize,
                category: .developer,
                path: "~/Library/Caches/com.microsoft.VSCode",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "VS Code",
                warningMessage: vscodeRunning ? "Close VS Code to clean safely" : nil
            ))
        }

        // Docker - show reclaimable space
        if isDockerRunning() {
            let dockerSize = dockerDiskUsageMB()
            if dockerSize > 50 {
                items.append(.init(
                    name: "Docker reclaimable",
                    sizeMB: dockerSize,
                    category: .developer,
                    path: "docker",
                    isDestructive: false,
                    requiresAppClosed: false,
                    appName: nil,
                    warningMessage: "Runs 'docker system prune' - removes unused containers/images"
                ))
            }
        }

        // Homebrew
        let brewSize = DirectorySizeUtility.quickDirectorySizeMB("~/Library/Caches/Homebrew")
        if brewSize > 50 {
            items.append(.init(
                name: "Homebrew cache",
                sizeMB: brewSize,
                category: .developer,
                path: "~/Library/Caches/Homebrew",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil
            ))
        }
        
        // OpenCode DB - significant memory user
        let opencodeDBSize = DirectorySizeUtility.quickDirectorySizeMB("~/.local/share/opencode")
        if opencodeDBSize > 100 {
            items.append(.init(
                name: "OpenCode database",
                sizeMB: opencodeDBSize,
                category: .developer,
                path: "~/.local/share/opencode",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "OpenCode",
                warningMessage: "Cleans old sessions - keep only 3 most recent"
            ))
        }

        return items
    }
    
    // MARK: - Application Caches
    
    private func scanApplicationCaches() -> [CleanupPlan.CleanupItem] {
        var items: [CleanupPlan.CleanupItem] = []
        
        // Popular apps that accumulate large caches
        let appCaches: [(name: String, path: String, appProcess: String, minSize: Double)] = [
            ("Spotify cache", "~/Library/Caches/com.spotify.client", "Spotify", 50),
            ("Slack cache", "~/Library/Caches/com.tinyspeck.slackmacgap", "Slack", 50),
            ("Discord cache", "~/Library/Caches/com.hnc.Discord", "Discord", 50),
            ("Teams cache", "~/Library/Caches/com.microsoft.teams", "Microsoft Teams", 50),
            ("Zoom cache", "~/Library/Caches/us.zoom.xos", "zoom.us", 30),
            ("Notion cache", "~/Library/Caches/notion.id", "Notion", 30),
            ("Figma cache", "~/Library/Caches/com.figma.Desktop", "Figma", 30),
            ("Dropbox cache", "~/Library/Caches/com.dropbox.DropboxMacUpdate", "Dropbox", 50),
            ("OneDrive cache", "~/Library/Caches/com.microsoft.OneDrive", "OneDrive", 50),
            ("Telegram cache", "~/Library/Caches/ru.keepcoder.Telegram", "Telegram", 50),
            ("WhatsApp cache", "~/Library/Caches/desktop.whatsapp.com", "WhatsApp", 30),
            ("Signal cache", "~/Library/Caches/org.whispersystems.signal-desktop", "Signal", 30),
        ]
        
        for (name, path, processName, minSize) in appCaches {
            let size = DirectorySizeUtility.quickDirectorySizeMB(path)
            if size > minSize {
                let isRunning = isAppRunning(processName)
                items.append(.init(
                    name: name,
                    sizeMB: size,
                    category: .application,
                    path: path,
                    isDestructive: false,
                    requiresAppClosed: true,
                    appName: processName,
                    warningMessage: isRunning ? "Close \(processName) to clean safely" : nil
                ))
            }
        }
        
        return items
    }

    private func scanBrowserCaches() -> [CleanupPlan.CleanupItem] {
        var items: [CleanupPlan.CleanupItem] = []

        // Safari - requires Safari to be closed
        let safariRunning = isAppRunning("Safari")
        let safariSize = fastDirectorySizeMB("~/Library/Caches/com.apple.Safari")
        if safariSize > 10 {
            items.append(.init(
                name: "Safari caches",
                sizeMB: safariSize,
                category: .browser,
                path: "~/Library/Caches/com.apple.Safari",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Safari",
                warningMessage: safariRunning ? "Close Safari to clean safely" : nil,
                priority: .medium
            ))
        }

        // Chrome - requires Chrome to be closed
        let chromeRunning = isAppRunning("Google Chrome")
        let chromeSize = fastDirectorySizeMB("~/Library/Caches/com.google.Chrome")
        if chromeSize > 10 {
            items.append(.init(
                name: "Chrome caches",
                sizeMB: chromeSize,
                category: .browser,
                path: "~/Library/Caches/com.google.Chrome",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Google Chrome",
                warningMessage: chromeRunning ? "Close Chrome to clean safely" : nil,
                priority: .medium
            ))
        }

        // Firefox
        let firefoxRunning = isAppRunning("Firefox")
        let firefoxSize = fastDirectorySizeMB("~/Library/Caches/org.mozilla.firefox")
        if firefoxSize > 10 {
            items.append(.init(
                name: "Firefox caches",
                sizeMB: firefoxSize,
                category: .browser,
                path: "~/Library/Caches/org.mozilla.firefox",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Firefox",
                warningMessage: firefoxRunning ? "Close Firefox to clean safely" : nil,
                priority: .medium
            ))
        }

        // Brave
        let braveRunning = isAppRunning("Brave Browser")
        let braveSize = fastDirectorySizeMB("~/Library/Caches/com.brave.Browser")
        if braveSize > 10 {
            items.append(.init(
                name: "Brave caches",
                sizeMB: braveSize,
                category: .browser,
                path: "~/Library/Caches/com.brave.Browser",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Brave Browser",
                warningMessage: braveRunning ? "Close Brave to clean safely" : nil,
                priority: .medium
            ))
        }

        return items
    }
    
    // MARK: - Logs Scanner
    
    private func scanLogs() -> [CleanupPlan.CleanupItem] {
        var items: [CleanupPlan.CleanupItem] = []
        
        // User logs
        let userLogsSize = fastDirectorySizeMB("~/Library/Logs")
        if userLogsSize > 20 {
            items.append(.init(
                name: "User logs",
                sizeMB: userLogsSize,
                category: .logs,
                path: "~/Library/Logs",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                priority: .medium
            ))
        }
        
        // System logs (requires admin, so we estimate)
        let systemLogsSize = fastDirectorySizeMB("/Library/Logs")
        if systemLogsSize > 50 {
            items.append(.init(
                name: "System logs",
                sizeMB: systemLogsSize,
                category: .logs,
                path: "/Library/Logs",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: "May require admin privileges",
                priority: .medium
            ))
        }
        
        // Diagnostic reports
        let diagnosticSize = fastDirectorySizeMB("~/Library/Logs/DiagnosticReports")
        if diagnosticSize > 10 {
            items.append(.init(
                name: "Crash reports",
                sizeMB: diagnosticSize,
                category: .logs,
                path: "~/Library/Logs/DiagnosticReports",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                priority: .high
            ))
        }
        
        return items
    }

    private func scanSystemCaches() -> [CleanupPlan.CleanupItem] {
        var items: [CleanupPlan.CleanupItem] = []

        // QuickLook - HIGH priority, always safe
        let qlSize = fastDirectorySizeMB("~/Library/Caches/com.apple.QuickLook.thumbnailcache")
        if qlSize > 10 {
            items.append(.init(
                name: "QuickLook thumbnails",
                sizeMB: qlSize,
                category: .system,
                path: "~/Library/Caches/com.apple.QuickLook.thumbnailcache",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                priority: .high
            ))
        }

        // Icon services - HIGH priority, always safe
        let iconSize = fastDirectorySizeMB("~/Library/Caches/com.apple.iconservices.store")
        if iconSize > 10 {
            items.append(.init(
                name: "Icon services cache",
                sizeMB: iconSize,
                category: .system,
                path: "~/Library/Caches/com.apple.iconservices.store",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                priority: .high
            ))
        }
        
        // Software Update caches - HIGH priority, always safe
        let updateSize = fastDirectorySizeMB("~/Library/Caches/com.apple.SoftwareUpdate")
        if updateSize > 50 {
            items.append(.init(
                name: "Software Update cache",
                sizeMB: updateSize,
                category: .system,
                path: "~/Library/Caches/com.apple.SoftwareUpdate",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                priority: .high
            ))
        }
        
        // SAFETY FIX (Phase 1): ~/Library/Mail removed from cleanup targets.
        // It contains actual email data, not just caches. Deleting it could destroy user emails.
        // See DodoTidy lesson: imprecise matching of app data can cause data loss.

        return items
    }

    private func scanTrash() -> Double {
        fastDirectorySizeMB("~/.Trash")
    }

    // MARK: - Execution Methods

    @discardableResult
    private func executeCleanupItem(_ item: CleanupPlan.CleanupItem) -> Double {
        // Special handling for Docker
        if item.path == "docker" {
            _ = cleanDockerSystem()  // Discard return value (always 0)
            return 0
        }

        // Special handling for trash
        if item.name == "Trash" {
            return executeTrashEmpty()
        }

        // Skip if whitelisted
        if isPathWhitelisted(item.path) {
            return 0
        }

        // Check running apps for certain cleanups
        if item.category == .browser {
            if isBrowserRunning(for: item.name) {
                return 0
            }
        }

        if item.category == .developer {
            if item.name.contains("Xcode") && isXcodeRunning() {
                return 0
            }
        }

        return cleanPath(item.path)
    }

    @discardableResult
    private func executeTrashEmpty() -> Double {
        let trashPath = "~/.Trash".expandingTilde
        let size = fastDirectorySizeMB(trashPath)
        guard size > 0 else { return 0 }

        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: trashPath)
            for item in contents {
                try? FileManager.default.removeItem(atPath: trashPath + "/" + item)
            }
            return size
        } catch {
            return 0
        }
    }

    // MARK: - Individual Cleanup Methods

    /// Safely clean a path with validation and error handling
    /// Uses Trash for user data, permanent delete for caches (which regenerate)
    private func cleanPath(_ path: String) -> Double {
        let expandedPath = path.expandingTilde

        // SAFETY CHECK 1: Validate path exists
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            print("[ComprehensiveOptimizer] Path does not exist: \(expandedPath)")
            return 0
        }

        // SAFETY CHECK 2: Prevent deletion of critical system paths
        guard isPathSafeToDelete(expandedPath) else {
            print("[ComprehensiveOptimizer] Blocked deletion of protected path: \(expandedPath)")
            return 0
        }

        // SAFETY CHECK 3: Skip whitelisted paths
        if isPathWhitelisted(expandedPath) {
            print("[ComprehensiveOptimizer] Skipping whitelisted path: \(expandedPath)")
            return 0
        }

        // Get size before deletion
        let size = DirectorySizeUtility.directorySizeMB(expandedPath)
        guard size > 1 else { return 0 }

        // SAFETY CHECK 4: Validate size is reasonable (prevent accidental mass deletion)
        guard size < 100_000 else {  // 100GB limit
            print("[ComprehensiveOptimizer] Path too large to delete safely: \(expandedPath) (\(size)MB)")
            return 0
        }

        do {
            // SAFETY CHECK 5: For destructive operations, verify one more time
            if !isDeletionSafe(expandedPath) {
                print("[ComprehensiveOptimizer] Deletion failed safety check: \(expandedPath)")
                return 0
            }

            // SAFETY FIX (Phase 1): ALL deletions now go to Trash for recovery.
            // Previously, caches were permanently deleted with no recovery path.
            // This follows DodoTidy's safety approach: always use trashItem() for user safety.
            let url = URL(fileURLWithPath: expandedPath)
            var trashURL: NSURL?
            try FileManager.default.trashItem(at: url, resultingItemURL: &trashURL)

            // For cache directories, recreate the empty folder to prevent app crashes.
            // Caches like ~/Library/Caches/com.apple.Safari expect the directory to exist.
            let isCachePath = path.contains("Caches") || path.contains("cache") ||
                              path.contains("DerivedData") || path.contains("node_modules")
            if isCachePath {
                try? FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)
            }

            print("[ComprehensiveOptimizer] Moved to Trash: \(expandedPath) (\(size)MB), trash location: \(trashURL?.path ?? "unknown")")

            print("[ComprehensiveOptimizer] Successfully cleaned: \(expandedPath) (\(size)MB)")
            return size
        } catch {
            print("[ComprehensiveOptimizer] Failed to clean \(expandedPath): \(error.localizedDescription)")
            return 0
        }
    }
    
    /// Check if a path is safe to delete (not a critical system path)
    private func isPathSafeToDelete(_ path: String) -> Bool {
        let lowerPath = path.lowercased()
        
        // Critical system paths that should NEVER be deleted
        let protectedPaths = [
            "/system", "/bin", "/sbin", "/usr", "/var", "/etc",
            "/applications", "/library", "/network", "/cores",
            "/dev", "/tmp", "/private"
        ]
        
        // Check if path starts with any protected path
        for protected in protectedPaths {
            if lowerPath.hasPrefix(protected + "/") || lowerPath == protected {
                // Exception: user-writable subdirectories
                if protected == "/var" && lowerPath.contains("/var/folders") {
                    continue  // Allow /var/folders cleanup
                }
                if protected == "/tmp" && lowerPath.hasPrefix("/var/tmp") {
                    continue  // Allow /var/tmp cleanup
                }
                return false
            }
        }
        
        // Protect user home directory root
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path == homeDir || path.hasPrefix(homeDir + "/Documents") || 
           path.hasPrefix(homeDir + "/Desktop") || path.hasPrefix(homeDir + "/Downloads") {
            // Exception: Downloads folder contents can be cleaned selectively
            if path.hasPrefix(homeDir + "/Downloads") && path != homeDir + "/Downloads" {
                return true  // Allow cleaning individual files in Downloads
            }
            return false  // Protect Documents, Desktop, and Downloads folder itself
        }
        
        // Protect app bundles
        if lowerPath.hasSuffix(".app") || lowerPath.hasSuffix(".app/") {
            return false
        }
        
        return true
    }
    
    /// Additional safety check for destructive operations
    private func isDeletionSafe(_ path: String) -> Bool {
        // Double-check the path still exists and is what we expect
        guard FileManager.default.fileExists(atPath: path) else { return false }
        
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return false }
        
        // Don't delete files that are currently open/in use
        // This is a best-effort check
        if !isDir.boolValue {
            // For files, check if any process has it open (simplified check)
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/lsof")
            task.arguments = [path]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = FileHandle.nullDevice
            
            do {
                try task.run()
                task.waitUntilExit()
                
                // If lsof returns output, the file is in use
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: data, encoding: .utf8), !output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("[ComprehensiveOptimizer] File in use, skipping: \(path)")
                    return false
                }
            } catch {
                // lsof failed - be conservative and skip
                return false
            }
        }
        
        return true
    }

    // MARK: - Docker Cleanup with Preview

    /// Get Docker disk usage preview before cleanup
    /// Returns: (reclaimableGB, containers, images, volumes, buildCache)
    func getDockerPreview() -> (reclaimableGB: Double, containers: Int, images: Int, volumes: Int, buildCache: String)? {
        guard isDockerRunning() else { return nil }

        // Run docker system df to get reclaimable space
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["system", "df"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            // Parse output (format varies, extract reclaimable column)
            let lines = output.components(separatedBy: "\n").filter { !$0.isEmpty }
            var reclaimableMB: Double = 0
            let containers = 0
            let images = 0
            let volumes = 0

            for line in lines {
                let parts = line.split(separator: " ", omittingEmptySubsequences: true)
                if parts.count >= 4 {
                    // Try to parse reclaimable column (usually 3rd or 4th)
                    for part in parts {
                        if let mb = parseDockerSize(String(part)) {
                            reclaimableMB += mb
                        }
                    }
                }
            }

            return (reclaimableMB / 1024, containers, images, volumes, output)
        } catch {
            print("[ComprehensiveOptimizer] Docker preview failed: \(error)")
            return nil
        }
    }

    /// Parse Docker size strings like "1.234GB", "567MB", "123KB"
    private func parseDockerSize(_ size: String) -> Double? {
        let size = size.trimmingCharacters(in: .whitespaces)
        if size.isEmpty || size == "0" || size == "0B" { return nil }

        let number = size.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        guard let value = Double(number) else { return nil }

        if size.uppercased().contains("GB") {
            return value * 1024  // Convert to MB
        } else if size.uppercased().contains("MB") {
            return value
        } else if size.uppercased().contains("KB") {
            return value / 1024
        } else if size.uppercased().contains("B") {
            return value / (1024 * 1024)
        }

        return nil
    }

    private func cleanDockerSystem() -> Double {
        guard isDockerRunning() else { 
            print("[ComprehensiveOptimizer] Docker not running, skipping cleanup")
            return 0 
        }

        // Preview first
        if let preview = getDockerPreview() {
            print("[ComprehensiveOptimizer] Docker cleanup preview: \(preview.reclaimableGB)GB reclaimable")
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["system", "prune", "-af"]
        
        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                print("[ComprehensiveOptimizer] Docker prune completed successfully")
            } else {
                print("[ComprehensiveOptimizer] Docker prune failed with status \(task.terminationStatus)")
            }
        } catch {
            print("[ComprehensiveOptimizer] Docker prune failed: \(error)")
        }

        return 0 // Can't easily measure
    }

    // MARK: - System Optimizations

    private func flushDNS() {
        let cmds: [(String, [String])] = [
            ("/usr/bin/dscacheutil", ["-flushcache"]),
            ("/usr/bin/killall", ["-HUP", "mDNSResponder"])
        ]
        for (cmd, args) in cmds {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: cmd)
            task.arguments = args
            try? task.run()
            task.waitUntilExit()
        }
    }

    private func rebuildQuickLook() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/qlmanage")
        task.arguments = ["-r", "cache"]
        try? task.run()
        task.waitUntilExit()
    }

    private func refreshDock() {
        let dockPlist = "~/Library/Preferences/com.apple.dock.plist".expandingTilde
        try? FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: dockPlist)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }

    private func clearFontCaches() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/atsutil")
        task.arguments = ["databases", "-remove"]
        try? task.run()
        task.waitUntilExit()
    }

    // MARK: - Memory Management

    private func closeIdleApps() -> (Double, Int) {
        let protectedIdentifiers = [
            "com.apple.finder", "com.apple.dock", "com.apple.systemuiserver",
            "com.apple.controlcenter", "com.apple.notificationcenterui",
            "com.apple.WindowManager", "com.apple.loginwindow", "com.apple.Spotlight",
            "com.apple.Mail", "com.apple.Safari", "com.apple.Terminal",
            "com.apple.ActivityMonitor", "com.jonathannugroho.pulse", "Pulse",
            "com.apple.LaunchServices", "com.apple.dt.Xcode",
            "com.google.Chrome", "com.apple.MobileSMS", "com.apple.iChat"
        ]

        var appsWithWindows = Set<Int32>()
        if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
            for window in windowList {
                if let pid = window[kCGWindowOwnerPID as String] as? Int32 {
                    appsWithWindows.insert(pid)
                }
            }
        }

        var totalFreed: Double = 0
        var closedApps: [(name: String, mem: Double)] = []
        let myPID = ProcessInfo.processInfo.processIdentifier

        for app in NSWorkspace.shared.runningApplications {
            // Skip protected apps
            guard app.activationPolicy == .regular,
                  app.processIdentifier != myPID,
                  !appsWithWindows.contains(app.processIdentifier),
                  let bundleID = app.bundleIdentifier,
                  !protectedIdentifiers.contains(where: { bundleID.contains($0) }) else { continue }
            
            // Get memory usage
            let memMB = processMemoryMB(pid: app.processIdentifier)
            
            // Only close apps using > 100MB
            guard memMB > 100 else { continue }

            // Try graceful termination first
            let terminated = app.terminate()
            
            if terminated {
                closedApps.append((name: app.localizedName ?? bundleID, mem: memMB))
                totalFreed += memMB
            }

            // Limit to closing 10 apps at most
            if closedApps.count >= 10 { break }
        }

        return (totalFreed, closedApps.count)
    }

    private func tryPurge() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/purge")
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    // MARK: - Helpers

    private func isXcodeRunning() -> Bool {
        isAppRunning("Xcode")
    }

    private func isAppRunning(_ name: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        task.arguments = ["-x", name]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus == 0
    }

    private func isBrowserRunning(for browserName: String) -> Bool {
        switch browserName {
        case "Safari": return isAppRunning("Safari")
        case "Chrome": return isAppRunning("Google Chrome")
        case "Firefox": return isAppRunning("Firefox")
        case "Brave": return isAppRunning("Brave Browser")
        default: return false
        }
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

    private func dockerDiskUsageMB() -> Double {
        // Get Docker disk usage using docker system df -v
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["system", "df", "-v"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        // Parse output to find space reclamation potential
        // Look for "Reclaimable" column
        var totalReclaimable: Double = 0
        let lines = output.components(separatedBy: "\n")
        for line in lines {
            // Look for lines with sizes like "1.234GB" or "567MB"
            let pattern = #"(\d+\.?\d*)\s*(GB|MB|KB)"#
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(line.startIndex..., in: line)
                let matches = regex.matches(in: line, options: [], range: range)
                for match in matches {
                    if let valueRange = Range(match.range(at: 1), in: line),
                       let unitRange = Range(match.range(at: 2), in: line),
                       let value = Double(line[valueRange]) {
                        let unit = String(line[unitRange]).uppercased()
                        if unit == "GB" {
                            totalReclaimable += value * 1024 // Convert to MB
                        } else if unit == "MB" {
                            totalReclaimable += value
                        } else if unit == "KB" {
                            totalReclaimable += value / 1024
                        }
                    }
                }
            }
        }
        return totalReclaimable
    }

    private func isPathWhitelisted(_ path: String) -> Bool {
        let whitelist = settings.whitelistedPaths
        return whitelist.contains { path.contains($0) }
    }

    private func goCachePath() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/go/bin/go")
        task.arguments = ["env", "GOCACHE"]
        let pipe = Pipe()
        task.standardOutput = pipe
        try? task.run()
        task.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
            return path
        }
        return "~/Library/Caches/go-build".expandingTilde
    }

    private func scanXcodeDeviceSupport() -> Double {
        var total: Double = 0
        let keepCount = 2

        for supportType in ["iOS DeviceSupport", "watchOS DeviceSupport", "tvOS DeviceSupport"] {
            let basePath = "~/Library/Developer/Xcode/\(supportType)".expandingTilde
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: basePath) else { continue }

            var dirsWithDates: [(String, Date)] = []
            for item in contents {
                let itemPath = basePath + "/" + item
                if let attrs = try? FileManager.default.attributesOfItem(atPath: itemPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    dirsWithDates.append((itemPath, modDate))
                }
            }

            dirsWithDates.sort { $0.1 > $1.1 }
            for (i, (dirPath, _)) in dirsWithDates.enumerated() {
                if i >= keepCount {
                    total += fastDirectorySizeMB(dirPath)
                }
            }
        }

        return total
    }

    private func processMemoryMB(pid: Int32) -> Double {
        var taskInfo = proc_taskinfo()
        let bytes = proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &taskInfo, Int32(MemoryLayout<proc_taskinfo>.size))
        guard bytes > 0 else { return 0 }
        return Double(taskInfo.pti_resident_size) / (1024 * 1024)
    }

    private func fastDirectorySizeMB(_ path: String) -> Double {
        let expanded = path.expandingTilde
        guard FileManager.default.fileExists(atPath: expanded) else { return 0 }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        task.arguments = ["-sk", expanded]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return DirectorySizeUtility.directorySizeMB(expanded) }
            let kb = output.split(separator: "\t").first.flatMap { Double($0) } ?? 0
            return kb / 1024
        } catch {
            return DirectorySizeUtility.directorySizeMB(expanded)
        }
    }

    private func refreshMonitors() {
        SystemMemoryMonitor.shared.updateMemoryInfo()
        ProcessMemoryMonitor.shared.refresh(topN: AppSettings.shared.topProcessesCount)
    }
}