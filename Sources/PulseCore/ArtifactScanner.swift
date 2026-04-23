//
//  ArtifactScanner.swift
//  PulseCore
//
//  Scans project directories for build artifacts (node_modules, .build, target, etc.).
//  No SwiftUI, no AppKit, no ObservableObject, no @Published.
//

import Foundation

/// Scans directories for build artifacts produced by developer tooling.
/// Results are returned as `ArtifactItem` values suitable for CLI display
/// or for integration with the existing CleanupPlan system.
public struct ArtifactScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    // MARK: - Scan

    /// Scan configured paths for build artifacts.
    /// Returns a list of `ArtifactItem` sorted by size (largest first).
    public func scan(config: ArtifactScanConfig) -> [ArtifactItem] {
        let now = Date()
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -config.minAgeDays, to: now) ?? now
        var items: [ArtifactItem] = []

        for scanPath in config.scanPaths {
            let expandedPath = (scanPath as NSString).expandingTildeInPath

            guard fileManager.fileExists(atPath: expandedPath),
                  let enumerator = fileManager.enumerator(
                    at: URL(fileURLWithPath: expandedPath),
                    includingPropertiesForKeys: [.isDirectoryKey, .contentModificationDateKey],
                    options: []
                  ) else {
                continue
            }

            while let item = enumerator.nextObject() as? URL {
                let path = item.path

                // Skip excluded paths (resolve symlinks for macOS /var → /private/var)
                let resolvedPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
                if config.excludedPaths.contains(where: { prefix in
                    let resolvedPrefix = URL(fileURLWithPath: prefix).resolvingSymlinksInPath().path
                    let normalized = resolvedPrefix.hasSuffix("/") ? resolvedPrefix : resolvedPrefix + "/"
                    return resolvedPath.hasPrefix(normalized) || resolvedPath == resolvedPrefix
                }) {
                    continue
                }

                // Check if this is an artifact directory
                let lastName = item.lastPathComponent
                guard let artifactType = config.artifactTypes.first(where: { $0.name == lastName }) else {
                    continue
                }

                // Verify it's a directory
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
                    continue
                }

                // Get size
                let sizeBytes = directorySize(at: item)
                let sizeMB = Double(sizeBytes) / (1024 * 1024)

                // Skip if below minimum size
                guard sizeMB >= config.minSizeMB else {
                    continue
                }

                // Get modification date
                let attributes = try? fileManager.attributesOfItem(atPath: path)
                let modDate = attributes?[.modificationDate] as? Date ?? now
                let ageDays = Calendar.current.dateComponents([.day], from: modDate, to: now).day ?? 0
                let isRecent = modDate > cutoffDate

                // Find the project path (parent directory of the artifact)
                let projectPath = item.deletingLastPathComponent().path

                let artifactItem = ArtifactItem(
                    projectPath: projectPath,
                    artifactName: artifactType.name,
                    artifactPath: path,
                    sizeMB: sizeMB,
                    lastModified: modDate,
                    ageDays: ageDays,
                    isRecent: isRecent,
                    type: artifactType,
                    action: artifactType.action
                )

                items.append(artifactItem)

                // Skip contents of this artifact directory (don't recurse into node_modules!)
                enumerator.skipDescendants()
            }
        }

        return items.sorted { $0.sizeMB > $1.sizeMB }
    }

    /// Convert scanned artifacts into a CleanupPlan for use with CleanupEngine.apply().
    /// This bridges the artifact scanner to the existing cleanup execution pipeline.
    public func plan(from artifacts: [ArtifactItem]) -> CleanupPlan {
        let items = artifacts.map { item in
            CleanupPlan.CleanupItem(
                name: "\(item.projectPath.split(separator: "/").last ?? "")/\(item.artifactName)",
                sizeMB: item.sizeMB,
                category: .developer,
                path: item.artifactPath,
                isDestructive: true,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: item.type.warning,
                skipReason: item.isRecent ? "Recently modified (\(item.ageDays) day(s) ago)" : nil,
                priority: item.priority,
                action: item.action,
                profile: .system
            )
        }

        let totalMB = items.reduce(0) { $0 + $1.sizeMB }

        return CleanupPlan(
            items: items,
            warnings: [],
            totalSizeMB: totalMB,
            timestamp: Date()
        )
    }

    // MARK: - Size Calculation

    /// Recursively calculate the total size of a directory in bytes.
    /// Uses a safe approach: enumerates contents and sums file sizes.
    private func directorySize(at path: URL) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: path,
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        while let item = enumerator.nextObject() as? URL {
            do {
                let values = try item.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey])
                if values.isDirectory != true, let size = values.fileSize {
                    total += Int64(size)
                }
            } catch {
                continue
            }
        }
        return total
    }
}
