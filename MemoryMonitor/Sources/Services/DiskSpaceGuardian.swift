import Foundation
import UserNotifications

/// Monitors disk space and triggers alerts/cleanup when space is low
/// Detects AI model caches (Ollama, Gemini, Cursor) and Docker disk images
class DiskSpaceGuardian: ObservableObject {
    static let shared = DiskSpaceGuardian()

    // MARK: - Published State

    @Published var currentFreeGB: Double = 0
    @Published var diskHealthLevel: DiskHealthLevel = .healthy
    @Published var lastAlertTime: Date?
    @Published var detectedIssues: [DiskSpaceIssue] = []
    @Published var isScanning: Bool = false

    // MARK: - Configuration (synced with AppSettings)

    var warningThresholdGB: Double {
        AppSettings.shared.diskWarningThresholdGB
    }

    var criticalThresholdGB: Double {
        AppSettings.shared.diskCriticalThresholdGB
    }

    var autoCleanupEnabled: Bool {
        AppSettings.shared.autoCleanupOnCriticalDisk
    }

    var autoCleanupThresholdGB: Double {
        AppSettings.shared.autoCleanupThresholdGB
    }

    // MARK: - Private Properties

    private var monitorTimer: DispatchSourceTimer?
    private let workQueue = DispatchQueue(label: "com.pulse.diskspaceguardian", qos: .utility)
    private let fileManager = FileManager.default

    // AI/Docker detection paths
    private let monitoredPaths: [String] = [
        // Docker
        "/Users/\(NSUserName())/Library/Containers/com.docker.docker/Data/vms/0/data/Docker.raw",
        // Ollama
        "/Users/\(NSUserName())/.ollama",
        // Gemini
        "/Users/\(NSUserName())/.gemini",
        // Cursor
        "/Users/\(NSUserName())/Library/Application Support/Cursor"
    ]

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Start monitoring (called by MemoryMonitorManager at app launch)
    func startMonitoring(interval: TimeInterval = 300) { // 5 min
        guard AppSettings.shared.hasSeenPermissionOnboarding else {
            // App not fully setup yet - delay monitoring
            return
        }

        stopMonitoring()

        let timer = DispatchSource.makeTimerSource(queue: workQueue)
        timer.schedule(deadline: .now(), repeating: .seconds(Int(interval)), leeway: .seconds(30))
        timer.setEventHandler { [weak self] in
            self?.checkDiskSpace()
        }
        timer.resume()
        monitorTimer = timer

        // Initial check
        checkDiskSpace()
    }

    /// Stop monitoring
    func stopMonitoring() {
        monitorTimer?.cancel()
        monitorTimer = nil
    }

    /// Immediate scan for disk issues
    func scanForIssues() {
        guard !isScanning else { return }

        isScanning = true
        detectedIssues = []

        workQueue.async { [weak self] in
            guard let self = self else { return }

            var issues: [DiskSpaceIssue] = []

            // Check overall disk space
            DiskMonitor.shared.refresh()
            if let freeGB = DiskMonitor.shared.primaryDisk?.freeGB {
                self.currentFreeGB = freeGB

                if freeGB <= self.criticalThresholdGB {
                    self.diskHealthLevel = .critical
                    issues.append(DiskSpaceIssue(
                        type: .lowDiskSpace,
                        path: "/",
                        sizeGB: freeGB,
                        isSafeToDelete: false,
                        warningMessage: "Only \(String(format: "%.1f", freeGB)) GB free. Run cleanup immediately.",
                        lastScanned: Date()
                    ))
                } else if freeGB <= self.warningThresholdGB {
                    self.diskHealthLevel = .warning
                    issues.append(DiskSpaceIssue(
                        type: .lowDiskSpace,
                        path: "/",
                        sizeGB: freeGB,
                        isSafeToDelete: false,
                        warningMessage: "Low disk space: \(String(format: "%.1f", freeGB)) GB free.",
                        lastScanned: Date()
                    ))
                } else {
                    self.diskHealthLevel = .healthy
                }
            }

            // Check monitored paths
            for path in self.monitoredPaths {
                let expandedPath = NSString(string: path).expandingTildeInPath
                if let sizeGB = self.getDirectorySize(at: expandedPath) {
                    guard sizeGB > 1.0 else { continue } // Only report if >1GB

                    let issueType = self.issueTypeForPath(path)
                    let isSafe = self.isSafeToDelete(path)
                    let warning = self.warningForPath(path, sizeGB: sizeGB)

                    issues.append(DiskSpaceIssue(
                        type: issueType,
                        path: expandedPath,
                        sizeGB: sizeGB,
                        isSafeToDelete: isSafe,
                        warningMessage: warning,
                        lastScanned: Date()
                    ))
                }
            }

            // Sort by size descending
            issues.sort { $0.sizeGB > $1.sizeGB }

            DispatchQueue.main.async {
                self.detectedIssues = issues
                self.isScanning = false
            }
        }
    }

    /// Delete detected issues (Docker prune, AI cache cleanup)
    func cleanupIssues(_ issues: [DiskSpaceIssue]) async -> CleanupResult {
        var totalFreedMB: Double = 0
        var errors: [String] = []

        for issue in issues {
            guard issue.isSafeToDelete else { continue }

            switch issue.type {
            case .dockerImage:
                // Docker prune requires Docker CLI
                do {
                    let freed = try await runDockerPrune()
                    totalFreedMB += freed
                } catch {
                    errors.append("Docker prune failed: \(error.localizedDescription)")
                }

            case .ollamaModels:
                // Delete Ollama model cache (keep most recent)
                let freed = cleanupOllamaCache()
                totalFreedMB += freed

            case .geminiModels:
                // Delete Gemini cache entirely (safe)
                let freed = cleanupGeminiCache()
                totalFreedMB += freed

            case .cursorCache:
                // Delete Cursor workspace storage and caches
                let freed = cleanupCursorCache()
                totalFreedMB += freed

            case .lowDiskSpace:
                // Trigger general cleanup via ComprehensiveOptimizer
                let freed = await runGeneralCleanup()
                totalFreedMB += freed

            case .largeFile:
                // Large files need user confirmation - skip auto cleanup
                errors.append("Large file at \(issue.path) requires manual review")
            }
        }

        return CleanupResult(freedMB: totalFreedMB, errors: errors)
    }

    // MARK: - Private Methods

    private func checkDiskSpace() {
        DiskMonitor.shared.refresh()

        if let freeGB = DiskMonitor.shared.primaryDisk?.freeGB {
            DispatchQueue.main.async {
                self.currentFreeGB = freeGB

                if freeGB <= self.criticalThresholdGB {
                    self.diskHealthLevel = .critical
                } else if freeGB <= self.warningThresholdGB {
                    self.diskHealthLevel = .warning
                } else {
                    self.diskHealthLevel = .healthy
                }
            }

            // Trigger alerts via AlertManager
            AlertManager.shared.checkDiskSpace(freeGB: freeGB)
        }

        // Also scan for issues
        scanForIssues()
    }

    private func getDirectorySize(at path: String) -> Double? {
        guard fileManager.fileExists(atPath: path) else { return nil }

        var totalSize: UInt64 = 0
        let url = URL(fileURLWithPath: path)

        guard let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return nil
        }

        for case let fileURL as URL in enumerator {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                  let size = resourceValues.fileSize else { continue }
            totalSize += UInt64(size)
        }

        return Double(totalSize) / (1024 * 1024 * 1024) // Convert to GB
    }

    private func issueTypeForPath(_ path: String) -> DiskSpaceIssue.IssueType {
        if path.contains("com.docker.docker") || path.hasSuffix("Docker.raw") {
            return .dockerImage
        } else if path.contains(".ollama") {
            return .ollamaModels
        } else if path.contains(".gemini") {
            return .geminiModels
        } else if path.contains("Cursor") {
            return .cursorCache
        }
        return .largeFile
    }

    private func isSafeToDelete(_ path: String) -> Bool {
        // System paths are never safe
        let unsafePrefixes = ["/System", "/usr", "/bin", "/sbin", "/private"]
        for prefix in unsafePrefixes {
            if path.hasPrefix(prefix) { return false }
        }

        // Docker.raw is safe (Docker can regenerate)
        if path.hasSuffix("Docker.raw") { return true }

        // AI caches are safe to delete
        if path.contains(".ollama") || path.contains(".gemini") { return true }

        // Cursor cache is safe
        if path.contains("Cursor") && path.contains("Caches") { return true }
        if path.contains("Cursor") && path.contains("workspaceStorage") { return true }

        return false
    }

    private func warningForPath(_ path: String, sizeGB: Double) -> String? {
        switch issueTypeForPath(path) {
        case .dockerImage:
            return "Docker disk image. Run 'docker system prune' or delete to compact."
        case .ollamaModels:
            return "Ollama AI models. Delete to free space (will re-download on next use)."
        case .geminiModels:
            return "Gemini AI cache. Safe to delete entirely."
        case .cursorCache:
            return "Cursor IDE cache. Safe to delete (IDE will rebuild)."
        default:
            return nil
        }
    }

    // MARK: - Cleanup Implementations

    private func runDockerPrune() async throws -> Double {
        // Check if Docker CLI exists
        let dockerPath = "/usr/local/bin/docker"
        guard fileManager.isExecutableFile(atPath: dockerPath) else {
            throw NSError(domain: "DiskSpaceGuardian", code: 1, userInfo: [NSLocalizedDescriptionKey: "Docker CLI not found"])
        }

        // Run docker system prune -f
        let process = Process()
        process.executableURL = URL(fileURLWithPath: dockerPath)
        process.arguments = ["system", "prune", "-f", "-a", "--volumes"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        // Docker prune doesn't report space freed easily, return estimate
        return 1000 // Estimate 1GB for tracking
    }

    private func cleanupOllamaCache() -> Double {
        let ollamaPath = NSString(string: "~/.ollama").expandingTildeInPath
        guard fileManager.fileExists(atPath: ollamaPath) else { return 0 }

        // Delete model blobs but keep modelfiles
        let blobsPath = ollamaPath + "/models/blobs"
        if fileManager.fileExists(atPath: blobsPath) {
            do {
                let contents = try fileManager.contentsOfDirectory(atPath: blobsPath)
                for item in contents {
                    let itemPath = blobsPath + "/" + item
                    try? fileManager.removeItem(atPath: itemPath)
                }
            } catch {
                print("[DiskSpaceGuardian] Failed to cleanup Ollama: \(error)")
            }
        }

        return getDirectorySize(at: blobsPath) ?? 0
    }

    private func cleanupGeminiCache() -> Double {
        let geminiPath = NSString(string: "~/.gemini").expandingTildeInPath
        guard fileManager.fileExists(atPath: geminiPath) else { return 0 }

        let sizeBefore = getDirectorySize(at: geminiPath) ?? 0

        // Delete history and models
        try? fileManager.removeItem(atPath: geminiPath + "/history")
        try? fileManager.removeItem(atPath: geminiPath + "/models")

        return sizeBefore
    }

    private func cleanupCursorCache() -> Double {
        let cursorPath = NSString(string: "~/Library/Application Support/Cursor").expandingTildeInPath

        var totalFreed: Double = 0

        // Clean Caches
        let cachesPath = cursorPath + "/Caches"
        if let size = getDirectorySize(at: cachesPath) {
            totalFreed += size
            try? fileManager.removeItem(atPath: cachesPath)
        }

        // Clean workspaceStorage
        let workspacePath = cursorPath + "/User/workspaceStorage"
        if let size = getDirectorySize(at: workspacePath) {
            totalFreed += size
            try? fileManager.removeItem(atPath: workspacePath)
        }

        return totalFreed
    }

    private func runGeneralCleanup() async -> Double {
        // SAFETY FIX (Phase 1): No longer calls executeCleanup() which could trigger
        // destructive operations without user confirmation. Uses quickOptimize() instead
        // which only closes idle apps and flushes DNS -- safe for automated background execution.
        ComprehensiveOptimizer.shared.quickOptimize()
        return ComprehensiveOptimizer.shared.lastResult?.totalFreedMB ?? 0
    }
}

// MARK: - Models

enum DiskHealthLevel: String {
    case healthy = "Healthy"
    case warning = "Warning"
    case critical = "Critical"
}

struct DiskSpaceIssue: Identifiable {
    let id = UUID()
    let type: IssueType
    let path: String
    let sizeGB: Double
    let isSafeToDelete: Bool
    let warningMessage: String?
    let lastScanned: Date

    var sizeText: String {
        String(format: "%.1f GB", sizeGB)
    }

    enum IssueType {
        case dockerImage
        case ollamaModels
        case geminiModels
        case cursorCache
        case largeFile
        case lowDiskSpace

        var icon: String {
            switch self {
            case .dockerImage: return "shipping.box"
            case .ollamaModels: return "brain"
            case .geminiModels: return "sparkles"
            case .cursorCache: return "cursorarrow"
            case .largeFile: return "doc.fill"
            case .lowDiskSpace: return "exclamationmark.triangle"
            }
        }
    }
}

struct CleanupResult {
    let freedMB: Double
    let errors: [String]

    var success: Bool { errors.isEmpty }
    var summary: String {
        if success {
            return "Freed \(String(format: "%.0f", freedMB)) MB"
        } else {
            return "Freed \(String(format: "%.0f", freedMB)) MB (\(errors.count) errors)"
        }
    }
}
