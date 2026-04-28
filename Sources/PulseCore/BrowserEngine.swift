//
//  BrowserEngine.swift
//  PulseCore
//
//  Scans for browser cache usage (Chrome, Edge, Safari).
//
//

import Foundation

public struct BrowserEngine {

    public init() {}

    private struct CacheDefinition {
        let name: String
        let path: String
        let minSizeMB: Double
        let warningMessage: String?

        static let all: [CacheDefinition] = [
            .init(
                name: "Google Chrome Cache",
                path: "~/Library/Caches/Google/Chrome",
                minSizeMB: 100,
                warningMessage: "Removes Chrome cache — pages may load slower initially"
            ),
            .init(
                name: "Microsoft Edge Cache",
                path: "~/Library/Caches/com.microsoft.Edge",
                minSizeMB: 100,
                warningMessage: "Removes Edge cache — pages may load slower initially"
            ),
            .init(
                name: "Safari Cache",
                path: "~/Library/Caches/Safari",
                minSizeMB: 100,
                warningMessage: "Removes Safari cache — pages may load slower initially"
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
                category: .browser,
                path: cache.path,
                isDestructive: false,
                requiresAppClosed: true,
                appName: "Browser",
                warningMessage: cache.warningMessage,
                priority: .high,
                action: .file,
                profile: .browser
            ))
        }

        return CleanupPlan(items: items, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }
}
