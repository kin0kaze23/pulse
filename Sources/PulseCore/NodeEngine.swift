//
//  NodeEngine.swift
//  PulseCore
//
//  Scans for Node.js package manager cache usage and applies cleanup via file deletion.
//  Pure Swift, no AppKit, SwiftUI, ObservableObject, or @Published.
//  File-based cleanup only — uses .file actions.
//

import Foundation

/// Engine for Node.js package manager cache scanning and cleanup.
/// Handles npm, yarn, and pnpm caches via file deletion (not command execution).
public struct NodeEngine {

    public init() {}

    /// Known Node package manager cache definitions.
    /// Only includes well-known, stable cache paths — no project-local node_modules.
    private struct CacheDefinition {
        let name: String
        let path: String
        let executable: String?  // nil = always scan (path exists check), non-nil = check executable
        let minSizeMB: Double    // threshold to include in plan
        let warningMessage: String?

        static let all: [CacheDefinition] = [
            .init(
                name: "npm cache",
                path: "~/.npm",
                executable: "npm",
                minSizeMB: 50,
                warningMessage: nil
            ),
            .init(
                name: "Yarn cache",
                path: "~/Library/Caches/Yarn",
                executable: "yarn",
                minSizeMB: 50,
                warningMessage: nil
            ),
            .init(
                name: "pnpm store",
                path: "~/Library/pnpm/store",
                executable: "pnpm",
                minSizeMB: 50,
                warningMessage: "Removes cached packages — reinstall may re-download"
            ),
        ]
    }

    // MARK: - Scan

    /// Scan for Node.js package manager caches. Returns a CleanupPlan.
    /// Returns an empty plan if no caches exceed thresholds.
    public func scan() -> CleanupPlan {
        var items: [CleanupPlan.CleanupItem] = []
        let scanner = DirectoryScanner()

        for cache in CacheDefinition.all {
            // If an executable is specified, skip if not installed
            if let executable = cache.executable,
               !isExecutableInstalled(executable) {
                continue
            }

            let size = scanner.directorySizeMB(cache.path)
            if size >= cache.minSizeMB {
                items.append(.init(
                    name: cache.name,
                    sizeMB: size,
                    category: .developer,
                    path: cache.path,
                    isDestructive: false,
                    requiresAppClosed: false,
                    appName: nil,
                    warningMessage: cache.warningMessage,
                    priority: .medium,
                    action: .file
                ))
            }
        }

        let totalSizeMB = items.reduce(0) { $0 + $1.sizeMB }
        return CleanupPlan(items: items, totalSizeMB: totalSizeMB)
    }

    // MARK: - Apply

    /// NodeEngine does not apply cleanup directly.
    /// Caches are file-based — CleanupEngine handles deletion via FileOperationPolicy.
    /// This method returns an empty result to satisfy the API contract.
    public func apply() -> CleanupResult {
        // File-based cleanup is handled by CleanupEngine.apply() via .file action.
        // NodeEngine.scan() produces items with action = .file, which CleanupEngine
        // routes to executeDelete() with the configured FileOperationPolicy.
        return CleanupResult(steps: [], skipped: [], totalFreedMB: 0)
    }

    // MARK: - Helpers

    /// Check if a command-line tool is installed by looking it up in PATH.
    /// Exposed for testing.
    func isExecutableInstalled(_ executable: String) -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        task.arguments = [executable]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }
}
