//
//  HomebrewEngine.swift
//  PulseCore
//
//  Scans for Homebrew cache usage and applies cleanup via `brew cleanup`.
//  Pure Swift, no AppKit, SwiftUI, ObservableObject, or @Published.
//

import Foundation

/// Engine for Homebrew cache scanning and cleanup.
/// Uses `brew` CLI commands — does NOT delete files directly.
public struct HomebrewEngine {
    private let brewExecutable: String

    public init(brewExecutable: String = "/opt/homebrew/bin/brew") {
        self.brewExecutable = brewExecutable
    }

    // MARK: - Scan

    /// Scan for Homebrew cache candidates. Returns a CleanupPlan.
    /// Returns an empty plan if Homebrew is not installed.
    public func scan() -> CleanupPlan {
        guard isHomebrewInstalled else {
            return CleanupPlan(items: [], totalSizeMB: 0)
        }

        var items: [CleanupPlan.CleanupItem] = []

        // Homebrew downloads cache
        let downloadsSize = cacheSizeMB(at: brewCacheDownloadsPath)
        if downloadsSize > 50 {
            items.append(.init(
                name: "Homebrew downloads",
                sizeMB: downloadsSize,
                category: .developer,
                path: brewCacheDownloadsPath,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: nil,
                priority: .medium,
                action: .command("brew cleanup --prune=all"),
                profile: .homebrew
            ))
        }

        // Homebrew cleanup reclaimable (old formulae/casks)
        let reclaimable = measureReclaimableMB()
        if reclaimable > 50 {
            items.append(.init(
                name: "Homebrew old versions",
                sizeMB: reclaimable,
                category: .developer,
                path: "homebrew://cleanup",
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: "Removes outdated formulae and cask versions",
                priority: .medium,
                action: .command("brew cleanup --prune=all"),
                profile: .homebrew
            ))
        }

        let totalSizeMB = items.reduce(0) { $0 + $1.sizeMB }
        return CleanupPlan(items: items, totalSizeMB: totalSizeMB)
    }

    // MARK: - Apply

    /// Execute Homebrew cleanup. Runs `brew cleanup --prune=all`.
    /// Returns a CleanupResult with the operation outcome.
    public func apply() -> CleanupResult {
        guard isHomebrewInstalled else {
            return CleanupResult(steps: [], skipped: [], totalFreedMB: 0)
        }

        var steps: [CleanupResult.Step] = []
        var skipped: [CleanupResult.SkippedItem] = []

        // Measure estimated reclaimable BEFORE cleanup so we can report it
        let estimatedReclaimable = measureReclaimableMB()

        // Run brew cleanup --prune=all
        let success = runBrewCleanup()

        if success {
            steps.append(.init(
                name: "Homebrew cleanup --prune=all",
                freedMB: estimatedReclaimable,
                success: true,
                category: .developer
            ))
        } else {
            skipped.append(.init(
                name: "Homebrew cleanup",
                reason: "brew cleanup command failed",
                sizeMB: 0
            ))
        }

        let totalFreedMB = steps.filter(\.success).reduce(0) { $0 + $1.freedMB }
        return CleanupResult(steps: steps, skipped: skipped, totalFreedMB: totalFreedMB)
    }

    // MARK: - Helpers

    /// Check if Homebrew is installed at the configured path.
    public var isHomebrewInstalled: Bool {
        let expandedPath = (brewExecutable as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: expandedPath)
    }

    private var brewCacheDownloadsPath: String {
        // Homebrew cache location — prefer HOMEBREW_CACHE env var if set
        if let envCache = ProcessInfo.processInfo.environment["HOMEBREW_CACHE"],
           !envCache.isEmpty {
            return envCache + "/downloads"
        }
        return "~/Library/Caches/Homebrew/downloads"
    }

    /// Measure the size of a Homebrew cache directory in MB.
    private func cacheSizeMB(at path: String) -> Double {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return 0
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        task.arguments = ["-sk", expandedPath]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8),
               let sizeKB = output.components(separatedBy: .whitespaces).first,
               let kb = Double(sizeKB) {
                return kb / 1024.0
            }
        } catch {}

        return 0
    }

    /// Estimate reclaimable space by parsing `brew cleanup --dry-run` output.
    /// Returns MB that could be freed, or 0 if brew is not installed.
    private func measureReclaimableMB() -> Double {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewExecutable)
        task.arguments = ["cleanup", "--dry-run"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else { return 0 }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }

            // Parse lines like: "/opt/homebrew/Cellar/pkg/1.0: 12.3MB *"
            // The last line is typically: "This operation would free approximately X.XXM of disk space."
            let lines = output.components(separatedBy: .newlines)
            for line in lines.reversed() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.lowercased().contains("free") || trimmed.lowercased().contains("reclaim") {
                    return parseSizeFromLine(trimmed)
                }
            }

            return 0
        } catch {
            return 0
        }
    }

    /// Parse a size value like "This would free 123.4MB" or "Free approximately 1.2GB"
    private func parseSizeFromLine(_ line: String) -> Double {
        let pattern = #"([\d.]+)\s*(GB|MB|KB)"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return 0
        }
        let nsRange = NSRange(line.startIndex..., in: line)
        guard let match = regex.firstMatch(in: line, options: [], range: nsRange) else {
            return 0
        }

        guard let valueRange = Range(match.range(at: 1), in: line),
              let unitRange = Range(match.range(at: 2), in: line),
              let value = Double(line[valueRange]) else {
            return 0
        }

        let unit = String(line[unitRange]).uppercased()
        switch unit {
        case "GB": return value * 1024
        case "MB": return value
        case "KB": return value / 1024
        default: return value
        }
    }

    /// Run `brew cleanup --prune=all`. Returns true on success.
    private func runBrewCleanup() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brewExecutable)
        task.arguments = ["cleanup", "--prune=all"]

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
