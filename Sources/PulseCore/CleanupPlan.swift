//
//  CleanupPlan.swift
//  PulseCore
//
//  Pure data types for cleanup planning and results.
//  No AppKit, SwiftUI, ObservableObject, or @Published.
//

import Foundation

// MARK: - Cleanup Profile

/// Profiles available for cleanup. v0.1 only supports Xcode.
public enum CleanupProfile: String, CaseIterable {
    case xcode
    // v0.2: case homebrew, case node, case docker, case browser, case system
}

// MARK: - Deletion Strategy

/// How files should be deleted during cleanup operations.
public enum DeletionStrategy {
    /// Move to Trash (recoverable). Default for user-facing cleanup.
    case trash
    /// Permanent deletion (not recoverable). Used for tests and automation.
    case permanent
}

// MARK: - File Operation Policy

/// Protocol for file deletion operations. Allows testing and policy injection
/// without coupling PulseCore to AppKit or UI concerns.
public protocol FileOperationPolicy {
    /// The default deletion strategy for this policy.
    var strategy: DeletionStrategy { get }

    /// Delete a path according to the policy.
    /// Returns true if the path was successfully removed.
    func delete(path: String) throws -> Bool
}

/// Default production policy: Trash-first with cache directory recreation.
public struct TrashFirstPolicy: FileOperationPolicy {
    public let strategy: DeletionStrategy = .trash

    public init() {}

    public func delete(path: String) throws -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return false
        }

        let url = URL(fileURLWithPath: expandedPath)
        var trashURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &trashURL)

        // Recreate cache directories that apps expect to exist.
        let isCachePath = path.contains("Caches") || path.contains("cache") ||
                          path.contains("DerivedData") || path.contains("node_modules") ||
                          path.contains("CoreSimulator") || path.contains("DeviceSupport") ||
                          path.contains("Archives")
        if isCachePath {
            try? FileManager.default.createDirectory(atPath: expandedPath, withIntermediateDirectories: true)
        }

        return true
    }
}

/// Permanent deletion policy. Used in tests and non-interactive contexts.
public struct PermanentDeletePolicy: FileOperationPolicy {
    public let strategy: DeletionStrategy = .permanent

    public init() {}

    public func delete(path: String) throws -> Bool {
        let expandedPath = (path as NSString).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return false
        }

        try FileManager.default.removeItem(atPath: expandedPath)
        return true
    }
}

// MARK: - Cleanup Config

/// Configuration for a cleanup scan/apply operation.
/// This is the ONLY interface between PulseApp and PulseCore.
/// No ObservableObject, no @Published, no singleton, no UserDefaults.
public struct CleanupConfig {
    /// Which profiles to include in the scan.
    public var profiles: Set<CleanupProfile>

    /// User-defined paths to always skip during cleanup.
    public var excludedPaths: [String]

    /// How files should be deleted. Defaults to .trash for user safety.
    public var deletionStrategy: DeletionStrategy

    /// File operation policy for deletion. Defaults to TrashFirstPolicy.
    /// Inject a custom policy to override deletion behavior (e.g. for testing).
    public var fileOperationPolicy: FileOperationPolicy

    public init(
        profiles: Set<CleanupProfile> = [.xcode],
        excludedPaths: [String] = [],
        deletionStrategy: DeletionStrategy = .trash,
        fileOperationPolicy: FileOperationPolicy? = nil
    ) {
        self.profiles = profiles
        self.excludedPaths = excludedPaths
        self.deletionStrategy = deletionStrategy
        self.fileOperationPolicy = fileOperationPolicy ?? TrashFirstPolicy()
    }
}

// MARK: - Cleanup Priority

/// Priority levels for cleanup items.
/// Higher priority = safer to delete, more recommended.
public enum CleanupPriority: String, CaseIterable, Codable, Comparable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"
    case optional = "Optional"

    /// Comparable: high > medium > low > optional
    public static func < (lhs: CleanupPriority, rhs: CleanupPriority) -> Bool {
        lhs.sortOrder > rhs.sortOrder
    }

    private var sortOrder: Int {
        switch self {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        case .optional: return 3
        }
    }
}

// MARK: - Cleanup Category

/// Categories for cleanup items.
public enum CleanupCategory: String, CaseIterable {
    case developer = "Developer"
    case browser = "Browser"
    case application = "Applications"
    case system = "System"
    case logs = "Logs"
}

// MARK: - Cleanup Plan

/// A plan of what can be cleaned, generated by a dry-run scan.
public struct CleanupPlan {
    public let items: [CleanupItem]
    public let warnings: [CleanupWarning]
    public let totalSizeMB: Double
    public let timestamp: Date

    public init(items: [CleanupItem], warnings: [CleanupWarning] = [], totalSizeMB: Double, timestamp: Date = Date()) {
        self.items = items
        self.warnings = warnings
        self.totalSizeMB = totalSizeMB
        self.timestamp = timestamp
    }

    public var totalSizeText: String {
        if totalSizeMB > 1024 {
            return String(format: "%.1f GB", totalSizeMB / 1024)
        }
        return String(format: "%.0f MB", totalSizeMB)
    }

    public var itemCount: Int { items.count }
    public var warningCount: Int { warnings.count }
    public var isSignificant: Bool { totalSizeMB > 50 }

    public struct CleanupItem {
        public let name: String
        public let sizeMB: Double
        public let category: CleanupCategory
        public let path: String
        public let isDestructive: Bool
        public let requiresAppClosed: Bool
        public let appName: String?
        public let warningMessage: String?
        public let priority: CleanupPriority
        public var skipReason: String?

        public init(
            name: String,
            sizeMB: Double,
            category: CleanupCategory,
            path: String,
            isDestructive: Bool,
            requiresAppClosed: Bool,
            appName: String?,
            warningMessage: String?,
            skipReason: String? = nil,
            priority: CleanupPriority = .medium
        ) {
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

        public var sizeText: String {
            if sizeMB > 1024 {
                return String(format: "%.1f GB", sizeMB / 1024)
            }
            return String(format: "%.0f MB", sizeMB)
        }
    }

    public struct CleanupWarning {
        public let message: String
        public let appName: String
        public let itemsAffected: Int

        public init(message: String, appName: String, itemsAffected: Int) {
            self.message = message
            self.appName = appName
            self.itemsAffected = itemsAffected
        }
    }
}

// MARK: - Cleanup Result

/// Result of an actual cleanup operation.
public struct CleanupResult {
    public let steps: [Step]
    public let skipped: [SkippedItem]
    public let totalFreedMB: Double
    public let timestamp: Date

    public init(steps: [Step], skipped: [SkippedItem] = [], totalFreedMB: Double, timestamp: Date = Date()) {
        self.steps = steps
        self.skipped = skipped
        self.totalFreedMB = totalFreedMB
        self.timestamp = timestamp
    }

    public var summary: String {
        let successCount = steps.filter(\.success).count
        if totalFreedMB > 1024 {
            return "\(successCount) actions · \(String(format: "%.1f GB", totalFreedMB / 1024)) freed"
        }
        return "\(successCount) actions · \(String(format: "%.0f MB", totalFreedMB)) freed"
    }

    public var successCount: Int { steps.filter(\.success).count }
    public var failureCount: Int { steps.filter { !$0.success }.count }

    public struct Step {
        public let name: String
        public let freedMB: Double
        public let success: Bool
        public let category: CleanupCategory?

        public init(name: String, freedMB: Double, success: Bool, category: CleanupCategory? = nil) {
            self.name = name
            self.freedMB = freedMB
            self.success = success
            self.category = category
        }
    }

    public struct SkippedItem {
        public let name: String
        public let reason: String
        public let sizeMB: Double

        public init(name: String, reason: String, sizeMB: Double) {
            self.name = name
            self.reason = reason
            self.sizeMB = sizeMB
        }
    }
}
