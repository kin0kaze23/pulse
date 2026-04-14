//
//  CleanupEngine.swift
//  PulseCore
//
//  Scans for cleanup candidates and applies cleanup operations.
//  Pure Swift, no AppKit, SwiftUI, ObservableObject, or @Published.
//  No AppSettings dependency -- receives CleanupConfig as input.
//

import Foundation

/// Engine for scanning and applying cleanup operations.
public struct CleanupEngine {
    private let scanner: DirectoryScanner

    public init(scanner: DirectoryScanner = DirectoryScanner()) {
        self.scanner = scanner
    }

    // MARK: - Scan (Dry-Run)

    /// Scan for cleanup candidates WITHOUT deleting anything.
    /// Returns a CleanupPlan showing what would be cleaned.
    public func scan(config: CleanupConfig) -> CleanupPlan {
        var items: [CleanupPlan.CleanupItem] = []

        if config.profiles.contains(.xcode) {
            items.append(contentsOf: scanXcode())
        }

        let totalSizeMB = items.reduce(0) { $0 + $1.sizeMB }
        return CleanupPlan(items: items, totalSizeMB: totalSizeMB)
    }

    // MARK: - Apply

    /// Execute a cleanup plan. Each item is validated before deletion.
    /// Returns a CleanupResult with what was actually cleaned.
    public func apply(plan: CleanupPlan, config: CleanupConfig) -> CleanupResult {
        let validator = SafetyValidator(excludedPaths: config.excludedPaths)
        var steps: [CleanupResult.Step] = []
        var skipped: [CleanupResult.SkippedItem] = []

        for item in plan.items {
            // Skip if user marked it as skipped
            if item.skipReason != nil {
                skipped.append(.init(name: item.name, reason: item.skipReason!, sizeMB: item.sizeMB))
                continue
            }

            // Validate path safety
            let expandedPath = (item.path as NSString).expandingTildeInPath
            guard validator.isPathSafeToDelete(expandedPath) else {
                skipped.append(.init(name: item.name, reason: "Protected path", sizeMB: item.sizeMB))
                continue
            }

            // Execute deletion
            let freedMB = executeDelete(item.path)
            steps.append(.init(
                name: item.name,
                freedMB: freedMB,
                success: freedMB > 0,
                category: item.category
            ))

            if freedMB == 0 && FileManager.default.fileExists(atPath: expandedPath) {
                skipped.append(.init(name: item.name, reason: "Deletion failed", sizeMB: item.sizeMB))
            }
        }

        let totalFreedMB = steps.filter(\.success).reduce(0) { $0 + $1.freedMB }
        return CleanupResult(steps: steps, skipped: skipped, totalFreedMB: totalFreedMB)
    }

    // MARK: - Xcode Scan

    private func scanXcode() -> [CleanupPlan.CleanupItem] {
        var items: [CleanupPlan.CleanupItem] = []

        // Xcode DerivedData (only if > 50 MB)
        let derivedDataSize = scanner.directorySizeMB("~/Library/Developer/Xcode/DerivedData")
        if derivedDataSize > 50 {
            items.append(.init(
                name: "Xcode DerivedData",
                sizeMB: derivedDataSize,
                category: .developer,
                path: "~/Library/Developer/Xcode/DerivedData",
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Xcode",
                warningMessage: nil,
                priority: .medium
            ))
        }

        // Xcode Archives (only if > 100 MB)
        let archivesSize = scanner.directorySizeMB("~/Library/Developer/Xcode/Archives")
        if archivesSize > 100 {
            items.append(.init(
                name: "Xcode Archives",
                sizeMB: archivesSize,
                category: .developer,
                path: "~/Library/Developer/Xcode/Archives",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: "Contains archived builds - delete only if you don't need them",
                priority: .low
            ))
        }

        // iOS DeviceSupport (only if > 100 MB)
        let deviceSize = scanner.directorySizeMB("~/Library/Developer/Xcode/iOS DeviceSupport")
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

        // iOS Simulators (only if > 500 MB)
        let simulatorSize = scanner.directorySizeMB("~/Library/Developer/CoreSimulator")
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

        return items
    }

    // MARK: - Delete

    /// Delete a path. Cache directories are permanently deleted (they regenerate).
    /// Returns the size freed in MB, or 0 if deletion failed.
    private func executeDelete(_ path: String) -> Double {
        let expandedPath = (path as NSString).expandingTildeInPath

        // Measure size before deletion
        let sizeBefore = scanner.directorySizeMB(path)

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return 0
        }

        do {
            try FileManager.default.removeItem(atPath: expandedPath)
            return sizeBefore
        } catch {
            return 0
        }
    }
}
