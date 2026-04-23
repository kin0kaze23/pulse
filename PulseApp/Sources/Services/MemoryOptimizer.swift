import Foundation
import AppKit
import Darwin
import Combine

/// Smart RAM and cache cleanup service - powered by ComprehensiveOptimizer with safety features
class MemoryOptimizer: ObservableObject {
    static let shared = MemoryOptimizer()

    // MARK: - Safety Thresholds

    /// Total size threshold (MB) above which review is required
    static let reviewThresholdMB: Double = 20 * 1024 // 20 GB

    /// Single item threshold (MB) above which review is required
    static let singleItemThresholdMB: Double = 10 * 1024 // 10 GB

    /// Total size threshold (MB) above which secondary confirmation is required
    static let confirmationThresholdMB: Double = 50 * 1024 // 50 GB

    @Published var isWorking = false
    @Published var lastResult: OptimizeResult?
    @Published var statusMessage: String = ""
    @Published var progress: Double = 0
    @Published var diskCleanupCandidates: [DiskCleanupCandidate] = []
    @Published var isScanningDiskCleanup = false
    @Published var showCleanupConfirmation = false
    @Published var pendingCleanupPlan: ComprehensiveOptimizer.CleanupPlan?

    /// Track which items are selected for cleanup (by ID)
    @Published var selectedItemIds: Set<UUID> = []

    /// Selected items based on selection state
    var selectedItems: [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        guard let plan = pendingCleanupPlan else { return [] }
        return plan.items.filter { selectedItemIds.contains($0.id) }
    }

    /// Total size of selected items
    var selectedTotalSizeMB: Double {
        selectedItems.reduce(0) { $0 + $1.sizeMB }
    }

    /// Total size of safe items (for MenuBarLite quick clean)
    var safeTotalSizeMB: Double {
        safeItems.reduce(0) { $0 + $1.sizeMB }
    }

    /// Whether there are any review or permanent items in the current plan
    var hasReviewItems: Bool {
        !reviewItems.isEmpty || !permanentItems.isEmpty
    }

    /// Initialize selections - default to safe items only
    func initializeSelections() {
        guard let plan = pendingCleanupPlan else { return }
        selectedItemIds = Set(plan.items.filter { isSafeToClean($0) }.map { $0.id })
    }

    /// Log a detailed proof table for verification
    func logProofTable(for plan: ComprehensiveOptimizer.CleanupPlan) {
        print("\n" + "=" .padding(toLength: 100, withPad: "=", startingAt: 0))
        print("CLEANUP PROOF TABLE - Total: \(plan.totalSizeText) (\(Int(plan.totalSizeMB)) MB)")
        print("=" .padding(toLength: 100, withPad: "=", startingAt: 0))

        let sortedItems = plan.items.sorted { $0.sizeMB > $1.sizeMB }

        print(String(format: "%-6s %-30s %-45s %12s %10s %-12s %-8s",
                    "#", "Label", "Path", "Est.Size", "Method", "Risk", "Default"))
        print("-" .padding(toLength: 100, withPad: "-", startingAt: 0))

        for (index, item) in sortedItems.enumerated() {
            let risk = riskLevel(for: item)
            let isDefault = selectedItemIds.contains(item.id) ? "YES" : "no"
            let method = "du -sk (fast)"

            let label = item.name.prefix(28)
            let path = item.path.prefix(43)

            print(String(format: "%-6d %-30s %-45s %10.0f MB %10s %-12s %-8s",
                        index + 1,
                        String(label),
                        String(path),
                        item.sizeMB,
                        method,
                        risk,
                        isDefault))
        }

        print("-" .padding(toLength: 100, withPad: "-", startingAt: 0))
        print("TOP CONTRIBUTORS:")
        for (index, item) in sortedItems.prefix(5).enumerated() {
            print("  \(index + 1). \(item.name): \(item.sizeMB > 1024 ? String(format: "%.1f GB", item.sizeMB/1024) : String(format: "%.0f MB", item.sizeMB))")
        }
        print("=" .padding(toLength: 100, withPad: "=", startingAt: 0))
        print("")
    }

    /// Determine risk level for an item
    private func riskLevel(for item: ComprehensiveOptimizer.CleanupPlan.CleanupItem) -> String {
        if item.isDestructive { return "MANUAL" }
        if item.sizeMB > Self.singleItemThresholdMB { return "REVIEW" }
        if isSafeToClean(item) { return "SAFE" }
        return "REVIEW"
    }

    /// Generate dry-run summary
    func logDryRunSummary() {
        guard let plan = pendingCleanupPlan else { return }

        print("\n" + "=" .padding(toLength: 80, withPad: "=", startingAt: 0))
        print("DRY-RUN SUMMARY - Cleanup Validation")
        print("=" .padding(toLength: 80, withPad: "=", startingAt: 0))

        let selected = selectedItems
        let selectedTotal = selectedTotalSizeMB

        print("Selected items: \(selected.count)")
        print("Selected total: \(selectedTotal > 1024 ? String(format: "%.1f GB", selectedTotal/1024) : String(format: "%.0f MB", selectedTotal))")
        print("")

        print("WILL BE DELETED:")
        for item in selected {
            print("  - \(item.name) (\(item.path)) - \(item.sizeMB > 1024 ? String(format: "%.1f GB", item.sizeMB/1024) : String(format: "%.0f MB", item.sizeMB))")
        }
        print("")

        let unselected = plan.items.filter { !selectedItemIds.contains($0.id) }
        print("WILL BE SKIPPED (\(unselected.count) items):")
        for item in unselected {
            let reason = riskLevel(for: item) == "MANUAL" ? "destructive" :
                        riskLevel(for: item) == "REVIEW" ? "review required" : "not safe"
            print("  - \(item.name): \(reason)")
        }
        print("=" .padding(toLength: 80, withPad: "=", startingAt: 0))
        print("")
    }

    /// Toggle selection for an item
    func toggleSelection(_ itemId: UUID) {
        if selectedItemIds.contains(itemId) {
            selectedItemIds.remove(itemId)
        } else {
            selectedItemIds.insert(itemId)
        }
    }

    /// Select all safe items
    func selectAllSafe() {
        guard let plan = pendingCleanupPlan else { return }
        selectedItemIds = Set(plan.items.filter { isSafeToClean($0) }.map { $0.id })
    }

    /// Deselect all items
    func deselectAll() {
        selectedItemIds.removeAll()
    }

    // MARK: - Safety State

    /// Whether the current cleanup plan requires review (total > 20GB or any item > 10GB)
    var requiresReview: Bool {
        guard let plan = pendingCleanupPlan else { return false }
        return plan.totalSizeMB > Self.reviewThresholdMB ||
               plan.items.contains { $0.sizeMB > Self.singleItemThresholdMB }
    }

    /// Whether the current cleanup plan requires explicit confirmation (total > 50GB)
    var requiresExplicitConfirmation: Bool {
        guard let plan = pendingCleanupPlan else { return false }
        return plan.totalSizeMB > Self.confirmationThresholdMB
    }

    /// Items that are clearly safe (small caches, rebuildable)
    var safeItems: [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        guard let plan = pendingCleanupPlan else { return [] }
        return plan.items.filter { isSafeToClean($0) }
    }

    /// Items that require review (large or potentially destructive)
    var reviewItems: [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        guard let plan = pendingCleanupPlan else { return [] }
        return plan.items.filter { !isSafeToClean($0) }
    }

    /// Items that are permanent/destructive - should never be auto-selected
    /// This includes Trash and explicitly destructive operations
    var permanentItems: [ComprehensiveOptimizer.CleanupPlan.CleanupItem] {
        guard let plan = pendingCleanupPlan else { return [] }
        return plan.items.filter { isPermanent($0) }
    }

    /// Check if an item is permanent (cannot be auto-cleaned safely)
    func isPermanent(_ item: ComprehensiveOptimizer.CleanupPlan.CleanupItem) -> Bool {
        // Trash is permanent deletion - must never be auto-selected
        if item.name == "Trash" { return true }

        // Explicitly destructive items
        if item.isDestructive { return true }

        // Very large items should require explicit user action
        if item.sizeMB > Self.singleItemThresholdMB { return true }

        return false
    }

    /// Check if a specific item is safe to auto-clean
    func isSafeToClean(_ item: ComprehensiveOptimizer.CleanupPlan.CleanupItem) -> Bool {
        // Trash is NEVER safe to auto-clean (permanent deletion)
        if item.name == "Trash" { return false }

        // Large items always require review
        if item.sizeMB > Self.singleItemThresholdMB { return false }

        // Items marked as destructive require review
        if item.isDestructive { return false }

        // Developer items need per-item check
        if item.category == .developer {
            // Safe developer caches (rebuildable)
            let safeDevPatterns = ["npm", "yarn", "pnpm", "pip", "gradle", "cargo", "go-build",
                                    "Homebrew", "TypeScript", "Vite", "bun", "JetBrains", "VS Code"]
            let isSafePattern = safeDevPatterns.contains { item.name.lowercased().contains($0.lowercased()) }
            return isSafePattern
        }

        // System caches under threshold are generally safe
        if item.category == .system && item.sizeMB < Self.singleItemThresholdMB {
            return true
        }

        // Browser caches are safe
        if item.category == .browser {
            return true
        }

        // Application caches are safe
        if item.category == .application {
            return true
        }

        // Default to review for unknown items
        return false
    }

    // Combine cancellables for completion waiting
    private var completionCancellable: AnyCancellable?
    private var scanCancellable: AnyCancellable?

    // MARK: - Disk Cleanup

    struct DiskCleanupCandidate: Identifiable {
        let id = UUID()
        let title: String
        let detail: String
        let sizeMB: Double
        let action: CleanupAction

        enum CleanupAction {
            case caches
            case trash
            case logs
            case downloads
            case developer
        }

        var sizeText: String {
            if sizeMB > 1024 {
                return String(format: "%.1f GB", sizeMB / 1024)
            }
            return String(format: "%.0f MB", sizeMB)
        }
    }

    private var comprehensive = ComprehensiveOptimizer.shared

    private init() {
        // Listen for confirmation requests from comprehensive optimizer
        _ = comprehensive.$needsConfirmation.sink { [weak self] needsConfirmation in
            DispatchQueue.main.async {
                self?.showCleanupConfirmation = needsConfirmation
            }
        }
        _ = comprehensive.$currentPlan.sink { [weak self] plan in
            DispatchQueue.main.async {
                self?.pendingCleanupPlan = plan
            }
        }
    }
    
    // MARK: - Combine-based Completion Waiting
    
    private func waitForComprehensiveCompletion(then completion: @escaping () -> Void) {
        completionCancellable?.cancel()
        completionCancellable = comprehensive.$isWorking
            .filter { !$0 }  // wait for isWorking to become false
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                completion()
                self?.completionCancellable = nil
            }
    }
    
    private func waitForScanCompletion(then completion: @escaping () -> Void) {
        scanCancellable?.cancel()
        scanCancellable = comprehensive.$isWorking
            .filter { !$0 }
            .first()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                completion()
                self?.scanCancellable = nil
            }
    }
    
    private func handleComprehensiveResult() {
        if let compResult = comprehensive.lastResult {
            let steps = compResult.steps.map { step in
                OptimizeResult.Step(
                    name: step.name,
                    freedMB: step.freedMB,
                    success: step.success
                )
            }
            let freedMB = compResult.totalFreedMB
            lastResult = OptimizeResult(
                steps: steps,
                totalFreedMB: freedMB,
                timestamp: compResult.timestamp
            )
            
            // Update cleanup history stats
            AppSettings.shared.totalFreedMB += freedMB
            AppSettings.shared.totalCleanupCount += 1
            AppSettings.shared.lastCleanupDate = Date()
        }
        isWorking = false
        progress = 1.0
        statusMessage = ""
        pendingCleanupPlan = nil
        showCleanupConfirmation = false
        refreshMonitors()
    }

    // MARK: - Free RAM (Main Action)

    /// Scan and show confirmation before cleanup (safe mode)
    func freeRAM() {
        guard !isWorking else { return }

        // Reset state
        showCleanupConfirmation = false
        pendingCleanupPlan = nil
        
        // First scan for cleanup
        comprehensive.scanForCleanup()
        isWorking = true
        statusMessage = "Scanning system..."
        progress = 0
        
        // Wait for scan completion using Combine
        waitForScanCompletion { [weak self] in
            guard let self = self else { return }
            self.progress = 1.0
            
            print("[MemoryOptimizer] Scan complete. needsConfirmation: \(self.comprehensive.needsConfirmation), hasPlan: \(self.comprehensive.currentPlan != nil)")
            
            // If confirmation needed, show dialog
            if self.comprehensive.needsConfirmation == true,
               let plan = self.comprehensive.currentPlan {
                self.isWorking = false  // Set to false so executeCleanup can run later
                self.statusMessage = ""
                self.pendingCleanupPlan = plan
                self.showCleanupConfirmation = true
                // Initialize selections - default to safe items only
                self.initializeSelections()

                // Log proof table for verification
                self.logProofTable(for: plan)

                // Log dry-run summary
                self.logDryRunSummary()

                print("[MemoryOptimizer] Showing confirmation dialog for \(plan.items.count) items, \(plan.totalSizeMB)MB")
            } else if let plan = self.comprehensive.currentPlan, plan.items.count > 0 {
                // Has plan but no confirmation needed - execute directly
                self.statusMessage = "Optimizing..."
                print("[MemoryOptimizer] Executing cleanup directly for \(plan.items.count) items")
                self.executeCleanup()
            } else {
                // No items found - do quick memory optimization
                self.isWorking = false  // Ensure isWorking is false after scan
                self.statusMessage = "Quick optimizing..."
                print("[MemoryOptimizer] No cleanup items, running quick optimize")
                self.quickOptimize()
            }
        }
        
        // Update progress periodically while scanning
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if !self.isWorking {
                timer.invalidate()
                return
            }
            self.progress = self.comprehensive.progress
            self.statusMessage = self.comprehensive.statusMessage
        }
    }

    /// Execute the pending cleanup plan
    func executeCleanup() {
        guard !isWorking else { 
            print("[MemoryOptimizer] executeCleanup blocked: isWorking=\(isWorking)")
            return 
        }
        
        // Dismiss confirmation dialog immediately
        showCleanupConfirmation = false
        
        print("[MemoryOptimizer] Starting cleanup execution for \(selectedItemIds.count) selected items")

        comprehensive.executeCleanup(selectedIds: selectedItemIds)

        isWorking = true
        statusMessage = "Cleaning up..."
        
        // Update progress periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if !self.isWorking {
                timer.invalidate()
                return
            }
            self.progress = self.comprehensive.progress
            self.statusMessage = self.comprehensive.statusMessage
        }

        // Wait for completion using Combine
        waitForComprehensiveCompletion { [weak self] in
            guard let self = self else { return }
            self.handleComprehensiveResult()
        }
    }

    /// Skip confirmation and cancel
    func cancelCleanup() {
        comprehensive.cancelPendingCleanup()
        isWorking = false
        showCleanupConfirmation = false
        pendingCleanupPlan = nil
        progress = 0
        statusMessage = ""
    }

    /// Quick memory-only optimization (no confirmation needed)
    func quickOptimize() {
        guard !isWorking else { return }
        comprehensive.quickOptimize()
        isWorking = true
        statusMessage = "Finding idle apps..."
        progress = 0.1
        
        // Update progress periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if !self.isWorking {
                timer.invalidate()
                return
            }
            self.progress = self.comprehensive.progress
            self.statusMessage = self.comprehensive.statusMessage
        }

        // Wait for completion using Combine
        waitForComprehensiveCompletion { [weak self] in
            guard let self = self else { return }
            self.handleComprehensiveResult()
        }
    }

    // MARK: - Quick Clean Caches (Fast, No Confirmation)

    /// Fast cache-only cleanup - no confirmation needed, safe to run anytime
    /// Cleans: Developer caches, browser caches, system caches, closes idle apps
    func quickCleanCaches() {
        guard !isWorking else { return }
        
        comprehensive.cacheOnlyOptimize()
        isWorking = true
        statusMessage = "Cleaning caches..."
        progress = 0.1
        
        // Update progress periodically
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            if !self.isWorking {
                timer.invalidate()
                return
            }
            self.progress = self.comprehensive.progress
            self.statusMessage = self.comprehensive.statusMessage
        }

        // Wait for completion using Combine
        waitForComprehensiveCompletion { [weak self] in
            guard let self = self else { return }
            self.handleComprehensiveResult()
        }
    }

    // MARK: - Refresh Monitors

    func refreshMonitors() {
        // Trigger memory monitor refresh after cleanup
        NotificationCenter.default.post(name: .memoryCleanupCompleted, object: nil)
    }

    // MARK: - Cache Size Estimation

    // Cached cache size to avoid blocking main thread
    @Published var cachedCacheSizeMB: Double = 0
    private var lastCacheScan: Date = .distantPast
    private let cacheScanInterval: TimeInterval = 60 // Re-scan every 60 seconds max

    /// Start async cache size scan (non-blocking)
    func refreshCacheSizeAsync() {
        // Don't scan too frequently
        guard Date().timeIntervalSince(lastCacheScan) > cacheScanInterval else { return }
        lastCacheScan = Date()
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let size = self.scanCacheSizeSync()
            DispatchQueue.main.async {
                self.cachedCacheSizeMB = size
            }
        }
    }

    /// Quick estimate of cache sizes for recommendations (non-destructive scan)
    /// Returns cached value if available, otherwise returns 0 and triggers async scan
    func scanCacheSize() -> Double {
        // Use the pending cleanup plan if available from a recent scan
        if let plan = pendingCleanupPlan {
            return plan.totalSizeMB
        }
        
        // Return cached value and trigger async refresh
        refreshCacheSizeAsync()
        return cachedCacheSizeMB
    }
    
    /// Synchronous cache scan - should only be called from background thread
    private func scanCacheSizeSync() -> Double {
        var totalMB: Double = 0

        // Quick estimate of common cache locations
        let home = FileManager.default.homeDirectoryForCurrentUser

        // npm cache
        let npmCache = home.appendingPathComponent(".npm")
        totalMB += estimateDirectorySize(at: npmCache)

        // yarn cache
        let yarnCache = home.appendingPathComponent(".yarn")
        totalMB += estimateDirectorySize(at: yarnCache)

        // pip cache
        let pipCache = home.appendingPathComponent(".cache/pip")
        totalMB += estimateDirectorySize(at: pipCache)

        // Xcode DerivedData (if enabled)
        if AppSettings.shared.cleanXcodeDerivedData {
            let derivedData = home.appendingPathComponent("Library/Developer/Xcode/DerivedData")
            totalMB += estimateDirectorySize(at: derivedData)
        }

        // System caches
        let systemCaches = home.appendingPathComponent("Library/Caches")
        totalMB += estimateDirectorySize(at: systemCaches)

        return totalMB
    }

    /// Estimate size of a directory in MB (quick scan)
    private func estimateDirectorySize(at url: URL) -> Double {
        DirectorySizeUtility.quickDirectorySizeMB(url.path, maxItems: 10_000)
    }
}

extension Notification.Name {
    static let memoryCleanupCompleted = Notification.Name("memoryCleanupCompleted")
}
