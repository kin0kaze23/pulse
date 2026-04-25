//
//  BunEngine.swift
//  PulseCore
//
//  Scans for Bun cache usage and cleanup opportunities.
//

import Foundation

public struct BunEngine {

    public init() {}

    private struct CacheDefinition {
        let name: String
        let path: String
        let minSizeMB: Double
        let warningMessage: String?

        static let all: [CacheDefinition] = [
            .init(
                name: "Bun install cache",
                path: "~/.bun/install/cache",
                minSizeMB: 50,
                warningMessage: "Removes cached packages — Bun will re-download them when needed"
            ),
        ]
    }

    public func scan() -> CleanupPlan {
        let scanner = DirectoryScanner()
        var items: [CleanupPlan.CleanupItem] = []

        for cache in CacheDefinition.all {
            let size = scanner.directorySizeMB(cache.path)
            guard size >= cache.minSizeMB else { continue }

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
                profile: .bun
            ))
        }

        return CleanupPlan(items: items, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }
}
