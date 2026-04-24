//
//  PythonEngine.swift
//  PulseCore
//
//  Scans for Python package/cache usage and applies cleanup via file deletion.
//  Pure Swift, no AppKit, SwiftUI, ObservableObject, or @Published.
//

import Foundation

/// Engine for Python cache scanning and cleanup.
/// Handles pip, Poetry, and uv caches via file deletion.
public struct PythonEngine {

    public init() {}

    private struct CacheDefinition {
        let name: String
        let path: String
        let minSizeMB: Double
        let warningMessage: String?

        static let all: [CacheDefinition] = [
            .init(
                name: "pip cache",
                path: "~/Library/Caches/pip",
                minSizeMB: 50,
                warningMessage: "Removes cached packages — reinstall may re-download"
            ),
            .init(
                name: "Poetry cache",
                path: "~/Library/Caches/pypoetry",
                minSizeMB: 50,
                warningMessage: "Removes cached packages — Poetry will re-download as needed"
            ),
            .init(
                name: "uv cache",
                path: "~/Library/Caches/uv",
                minSizeMB: 50,
                warningMessage: "Removes cached packages — uv will rebuild this cache when needed"
            ),
        ]
    }

    // MARK: - Scan

    public func scan() -> CleanupPlan {
        var items: [CleanupPlan.CleanupItem] = []
        let scanner = DirectoryScanner()

        for cache in CacheDefinition.all {
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
                    action: .file,
                    profile: .python
                ))
            }
        }

        let totalSizeMB = items.reduce(0) { $0 + $1.sizeMB }
        return CleanupPlan(items: items, totalSizeMB: totalSizeMB)
    }

    // MARK: - Apply

    public func apply() -> CleanupResult {
        CleanupResult(steps: [], skipped: [], totalFreedMB: 0)
    }
}
