//
//  CursorEngine.swift
//  PulseCore
//
//  Scans for Cursor IDE caches, logs, and workspace storage bloat.
//  Pure Swift, no AppKit, no SwiftUI, no ObservableObject, no @Published.
//

import Foundation

public struct CursorEngine {

    public init() {}

    private struct Target {
        let name: String
        let path: String
        let minSizeMB: Double
        let priority: CleanupPriority
        let warningMessage: String?

        static let all: [Target] = [
            .init(
                name: "Cursor cache",
                path: "~/Library/Application Support/Cursor/Cache",
                minSizeMB: 50,
                priority: .high,
                warningMessage: "Safe to remove after closing Cursor — recreated automatically"
            ),
            .init(
                name: "Cursor cached data",
                path: "~/Library/Application Support/Cursor/CachedData",
                minSizeMB: 50,
                priority: .high,
                warningMessage: "Safe to remove after closing Cursor — recreated automatically"
            ),
            .init(
                name: "Cursor code cache",
                path: "~/Library/Application Support/Cursor/Code Cache",
                minSizeMB: 50,
                priority: .high,
                warningMessage: "Safe to remove after closing Cursor — recreated automatically"
            ),
            .init(
                name: "Cursor logs",
                path: "~/Library/Application Support/Cursor/logs",
                minSizeMB: 20,
                priority: .high,
                warningMessage: "Safe to remove old logs after closing Cursor"
            ),
            .init(
                name: "Cursor cached extensions",
                path: "~/Library/Application Support/Cursor/CachedExtensionVSIXs",
                minSizeMB: 50,
                priority: .medium,
                warningMessage: "Safe to remove cached extension packages — they will re-download if needed"
            ),
            .init(
                name: "Cursor runtime cache",
                path: "~/Library/Caches/com.todesktop.runtime.Cursor",
                minSizeMB: 50,
                priority: .medium,
                warningMessage: "Safe to remove runtime caches after closing Cursor"
            ),
            .init(
                name: "Cursor workspace storage",
                path: "~/Library/Application Support/Cursor/User/workspaceStorage",
                minSizeMB: 250,
                priority: .low,
                warningMessage: "Review before removing — clears old workspace state, backups, and chat history"
            ),
        ]
    }

    public func scan() -> CleanupPlan {
        let scanner = DirectoryScanner()
        var items: [CleanupPlan.CleanupItem] = []

        for target in Target.all {
            let size = scanner.directorySizeMB(target.path)
            guard size >= target.minSizeMB else { continue }

            items.append(.init(
                name: target.name,
                sizeMB: size,
                category: .developer,
                path: target.path,
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Cursor",
                warningMessage: target.warningMessage,
                priority: target.priority,
                action: .file,
                profile: .cursor
            ))
        }

        return CleanupPlan(items: items, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }
}
