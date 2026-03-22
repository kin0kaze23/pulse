import Foundation
import AppKit
import Darwin
import Combine

/// Smart RAM and cache cleanup service - powered by ComprehensiveOptimizer with safety features
class MemoryOptimizer: ObservableObject {
    static let shared = MemoryOptimizer()

    @Published var isWorking = false
    @Published var lastResult: OptimizeResult?
    @Published var statusMessage: String = ""
    @Published var progress: Double = 0
    @Published var diskCleanupCandidates: [DiskCleanupCandidate] = []
    @Published var isScanningDiskCleanup = false
    @Published var showCleanupConfirmation = false
    @Published var pendingCleanupPlan: ComprehensiveOptimizer.CleanupPlan?
    
    // Combine cancellables for completion waiting
    private var completionCancellable: AnyCancellable?
    private var scanCancellable: AnyCancellable?

    struct OptimizeResult {
        let steps: [Step]
        let totalFreedMB: Double
        let timestamp: Date

        struct Step {
            let name: String
            let freedMB: Double
            let success: Bool
        }

        var summary: String {
            let successCount = steps.filter(\.success).count
            if totalFreedMB > 1024 {
                return "\(successCount) actions · \(String(format: "%.1f GB", totalFreedMB / 1024)) freed"
            }
            return "\(successCount) actions · \(String(format: "%.0f MB", totalFreedMB)) freed"
        }

        var detailLines: [String] {
            steps.map { step in
                let prefix = step.success ? "✓" : "✗"
                let size = step.freedMB > 1024
                    ? String(format: "%.1f GB", step.freedMB / 1024)
                    : String(format: "%.0f MB", step.freedMB)
                return "\(prefix) \(step.name): \(size)"
            }
        }
    }

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
                self.statusMessage = ""
                self.pendingCleanupPlan = plan
                self.showCleanupConfirmation = true
                print("[MemoryOptimizer] Showing confirmation dialog for \(plan.items.count) items, \(plan.totalSizeMB)MB")
            } else if let plan = self.comprehensive.currentPlan, plan.items.count > 0 {
                // Has plan but no confirmation needed - execute directly
                self.statusMessage = "Optimizing..."
                print("[MemoryOptimizer] Executing cleanup directly for \(plan.items.count) items")
                self.executeCleanup()
            } else {
                // No items found - do quick memory optimization
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
        guard !isWorking else { return }

        comprehensive.executeCleanup()

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
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: url.path) else { return 0 }

        var totalBytes: Int64 = 0
        let cursor = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        guard let enumerator = cursor else { return 0 }

        var count = 0
        for case let fileURL as URL in enumerator {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if resourceValues.isDirectory == false {
                    totalBytes += Int64(resourceValues.fileSize ?? 0)
                    count += 1
                    if count > 10000 { break } // Limit scan depth for performance
                }
            } catch { break }
        }

        return Double(totalBytes) / (1024 * 1024)
    }
}

extension Notification.Name {
    static let memoryCleanupCompleted = Notification.Name("memoryCleanupCompleted")
}
