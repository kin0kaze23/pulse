//
//  RustEngine.swift
//  PulseCore
//
//  Scans for Rust/Cargo cache usage and cleanup opportunities.
//

import Foundation

public struct RustEngine {

    public init() {}

    private struct CacheDefinition {
        let name: String
        let path: String
        let minSizeMB: Double
        let warningMessage: String?

        static let all: [CacheDefinition] = [
            .init(
                name: "Cargo registry cache",
                path: "~/.cargo/registry",
                minSizeMB: 50,
                warningMessage: "Removes downloaded crates — Cargo will fetch them again when needed"
            ),
            .init(
                name: "Cargo git cache",
                path: "~/.cargo/git",
                minSizeMB: 50,
                warningMessage: "Removes cached git dependencies — Cargo will clone them again when needed"
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
                profile: .rust
            ))
        }

        return CleanupPlan(items: items, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }
}
