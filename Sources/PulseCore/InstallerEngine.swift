//
//  InstallerEngine.swift
//  PulseCore
//
//  Scans for stale installer/archive files in common user locations.
//

import Foundation

public struct InstallerEngine {
    private let fileManager: FileManager
    private let scanRoots: [String]
    private let minAgeDays: Int
    private let minSizeMB: Double

    public init(
        fileManager: FileManager = .default,
        scanRoots: [String] = ["~/Downloads", "~/Desktop"],
        minAgeDays: Int = 14,
        minSizeMB: Double = 100
    ) {
        self.fileManager = fileManager
        self.scanRoots = scanRoots
        self.minAgeDays = minAgeDays
        self.minSizeMB = minSizeMB
    }

    private let allowedExtensions = [
        ".dmg", ".pkg", ".zip", ".tgz", ".tar", ".tar.gz", ".xz", ".7z",
    ]

    public func scan() -> CleanupPlan {
        var items: [CleanupPlan.CleanupItem] = []
        let now = Date()

        for root in scanRoots {
            let expandedRoot = NSString(string: root).expandingTildeInPath
            guard let children = try? fileManager.contentsOfDirectory(atPath: expandedRoot) else { continue }

            for child in children {
                let path = (expandedRoot as NSString).appendingPathComponent(child)
                var isDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: path, isDirectory: &isDirectory), !isDirectory.boolValue else { continue }
                guard isInstallerLike(child) else { continue }

                guard let attrs = try? fileManager.attributesOfItem(atPath: path),
                      let modDate = attrs[.modificationDate] as? Date,
                      let fileSize = attrs[.size] as? NSNumber else { continue }

                let ageDays = Calendar.current.dateComponents([.day], from: modDate, to: now).day ?? 0
                let sizeMB = Double(truncating: fileSize) / (1024 * 1024)

                guard ageDays >= minAgeDays, sizeMB >= minSizeMB else { continue }

                let warning = "Review before removing — you may still want this installer or archive for reinstallation/offline use"
                items.append(.init(
                    name: child,
                    sizeMB: sizeMB,
                    category: .application,
                    path: path,
                    isDestructive: false,
                    requiresAppClosed: false,
                    appName: nil,
                    warningMessage: warning,
                    priority: .low,
                    action: .file,
                    profile: .installers
                ))
            }
        }

        return CleanupPlan(items: items.sorted { $0.sizeMB > $1.sizeMB }, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }

    private func isInstallerLike(_ filename: String) -> Bool {
        let lower = filename.lowercased()
        return allowedExtensions.contains { lower.hasSuffix($0) }
    }
}
