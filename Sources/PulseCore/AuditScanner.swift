//
//  AuditScanner.swift
//  PulseCore
//
//  Scans for developer environment issues: stale simulators, orphaned taps,
//  dead symlinks, old toolchains, and other maintenance opportunities.
//  Pure Swift, no AppKit, no SwiftUI, no ObservableObject, no @Published.
//

import Foundation

// MARK: - Audit Issue

/// A single issue found during the audit scan.
public struct AuditIssue: Sendable {
    /// Machine-readable severity.
    public enum Severity: String, Codable, Sendable {
        /// Something is broken or wasting significant space.
        case critical
        /// Cleanup recommended but not urgent.
        case warning
        /// Informational — no action required.
        case info
    }

    /// Category of the issue for grouping in output.
    public enum Category: String, Codable, Sendable {
        case xcode = "Xcode"
        case homebrew = "Homebrew"
        case symlinks = "Symlinks"
        case toolchains = "Toolchains"
        case general = "General"
    }

    /// Short title describing the issue.
    public let title: String
    /// Detailed description or recommendation.
    public let description: String
    /// Estimated space that could be reclaimed (MB), if applicable.
    public let reclaimableMB: Double?
    /// How serious this issue is.
    public let severity: Severity
    /// Which category it belongs to.
    public let category: Category
    /// The path associated with this issue, if any.
    public let path: String?

    public init(
        title: String,
        description: String,
        reclaimableMB: Double? = nil,
        severity: Severity,
        category: Category,
        path: String? = nil
    ) {
        self.title = title
        self.description = description
        self.reclaimableMB = reclaimableMB
        self.severity = severity
        self.category = category
        self.path = path
    }
}

// MARK: - Audit Scanner

/// Scans the developer environment for maintenance opportunities.
public struct AuditScanner {
    private let fileManager: FileManager

    public init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    /// Run all audit checks and return a list of issues found.
    public func scan() -> [AuditIssue] {
        var issues: [AuditIssue] = []
        issues.append(contentsOf: scanXcodeSimulators())
        issues.append(contentsOf: scanXcodeArchives())
        issues.append(contentsOf: scanHomebrewOrphanedTaps())
        issues.append(contentsOf: scanDeadSymlinks())
        issues.append(contentsOf: scanXcodeToolchains())
        return issues
    }

    // MARK: - Xcode Simulators

    /// Check for old or unused CoreSimulator data.
    private func scanXcodeSimulators() -> [AuditIssue] {
        var issues: [AuditIssue] = []

        // Check for old simulators that haven't been booted recently
        let simDevicesPath = NSString(string: "~/Library/Developer/CoreSimulator/Devices").expandingTildeInPath
        guard fileManager.fileExists(atPath: simDevicesPath) else { return issues }

        let contents = (try? fileManager.contentsOfDirectory(atPath: simDevicesPath)) ?? []
        var totalSizeMB: Double = 0
        var oldCount = 0

        for deviceID in contents {
            let devicePath = (simDevicesPath as NSString).appendingPathComponent(deviceID)
            let plistPath = (devicePath as NSString).appendingPathComponent("device.plist")

            // Check if the device.plist exists and is old
            if fileManager.fileExists(atPath: plistPath),
               let attrs = try? fileManager.attributesOfItem(atPath: plistPath),
               let modDate = attrs[.modificationDate] as? Date,
               Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0 > 90 {
                let size = directorySizeMB(at: devicePath)
                totalSizeMB += size
                oldCount += 1
            }
        }

        if oldCount > 0 {
            issues.append(AuditIssue(
                title: "\(oldCount) simulator(s) inactive for 90+ days",
                description: "Run 'xcrun simctl delete unavailable' to remove unavailable runtimes.",
                reclaimableMB: totalSizeMB,
                severity: totalSizeMB > 5000 ? .critical : .warning,
                category: .xcode,
                path: simDevicesPath
            ))
        }

        // Check for CoreSimulator Caches
        let simCachesPath = NSString(string: "~/Library/Developer/CoreSimulator/Caches").expandingTildeInPath
        if fileManager.fileExists(atPath: simCachesPath) {
            let cacheSize = directorySizeMB(at: simCachesPath)
            if cacheSize > 500 {
                issues.append(AuditIssue(
                    title: "CoreSimulator caches using \(formatSize(cacheSize))",
                    description: "Safe to delete. Simulators will regenerate caches as needed.",
                    reclaimableMB: cacheSize,
                    severity: cacheSize > 2000 ? .critical : .warning,
                    category: .xcode,
                    path: simCachesPath
                ))
            }
        }

        return issues
    }

    // MARK: - Xcode Archives

    /// Check for old Xcode Archives that may no longer be needed.
    private func scanXcodeArchives() -> [AuditIssue] {
        var issues: [AuditIssue] = []

        let archivesPath = NSString(string: "~/Library/Developer/Xcode/Archives").expandingTildeInPath
        guard fileManager.fileExists(atPath: archivesPath) else { return issues }

        let size = directorySizeMB(at: archivesPath)
        if size > 1000 {
            issues.append(AuditIssue(
                title: "Xcode Archives using \(formatSize(size))",
                description: "Old archives can be safely deleted from Organizer or Finder.",
                reclaimableMB: size,
                severity: size > 5000 ? .critical : .warning,
                category: .xcode,
                path: archivesPath
            ))
        }

        return issues
    }

    // MARK: - Homebrew Orphaned Taps

    /// Check for Homebrew taps that are no longer being used.
    private func scanHomebrewOrphanedTaps() -> [AuditIssue] {
        var issues: [AuditIssue] = []

        let tapsPath = NSString(string: "$(brew --prefix)/Library/Taps").expandingTildeInPath
        // Use a subshell to get the actual brew prefix
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", "brew --prefix"]
        task.standardOutput = Pipe()
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0,
               let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
               let prefix = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                let realTapsPath = (prefix as NSString).appendingPathComponent("Library/Taps")

                guard fileManager.fileExists(atPath: realTapsPath) else { return issues }

                let tapDirs = (try? fileManager.contentsOfDirectory(atPath: realTapsPath)) ?? []
                for tapDir in tapDirs {
                    let tapPath = (realTapsPath as NSString).appendingPathComponent(tapDir)
                    let formulaDirs = (try? fileManager.contentsOfDirectory(atPath: tapPath)) ?? []

                    // Check if any formulae are actually installed from this tap
                    var hasInstalledFormulae = false
                    for formulaDir in formulaDirs {
                        let formulaPath = (tapPath as NSString).appendingPathComponent(formulaDir)
                        let rbFiles = (try? fileManager.contentsOfDirectory(atPath: formulaPath)) ?? []
                        for rbFile in rbFiles where rbFile.hasSuffix(".rb") {
                            let formulaName = (rbFile as NSString).deletingPathExtension
                            let checkTask = Process()
                            checkTask.executableURL = URL(fileURLWithPath: "/bin/bash")
                            checkTask.arguments = ["-c", "brew list --versions \(formulaName) >/dev/null 2>&1"]
                            checkTask.standardOutput = FileHandle.nullDevice
                            checkTask.standardError = FileHandle.nullDevice
                            try? checkTask.run()
                            checkTask.waitUntilExit()
                            if checkTask.terminationStatus == 0 {
                                hasInstalledFormulae = true
                                break
                            }
                        }
                        if hasInstalledFormulae { break }
                    }

                    if !hasInstalledFormulae && !tapDirs.isEmpty {
                        issues.append(AuditIssue(
                            title: "Orphaned tap: \(tapDir)",
                            description: "No formulae from this tap are installed. Remove with 'brew tap --remove \(tapDir)'.",
                            reclaimableMB: directorySizeMB(at: tapPath),
                            severity: .info,
                            category: .homebrew,
                            path: tapPath
                        ))
                    }
                }
            }
        } catch {
            // brew not installed or error — skip silently
        }

        return issues
    }

    // MARK: - Dead Symlinks

    /// Scan common developer directories for broken symlinks.
    private func scanDeadSymlinks() -> [AuditIssue] {
        var issues: [AuditIssue] = []
        let scanPaths = [
            NSString(string: "~/Developer").expandingTildeInPath,
            NSString(string: "~/Projects").expandingTildeInPath,
            NSString(string: "~/GitHub").expandingTildeInPath,
            NSString(string: "~/Code").expandingTildeInPath,
        ]

        var deadLinks: [(String, String)] = []

        for scanPath in scanPaths {
            guard fileManager.fileExists(atPath: scanPath) else { continue }

            let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: scanPath),
                includingPropertiesForKeys: [.isSymbolicLinkKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )

            while let item = enumerator?.nextObject() as? URL {
                let path = item.path
                let isSymlink = (try? item.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true

                if isSymlink && !fileManager.fileExists(atPath: path) {
                    deadLinks.append((path, scanPath))
                    // Don't recurse into broken symlinks
                    enumerator?.skipDescendants()
                }
            }
        }

        if !deadLinks.isEmpty {
            let linkList = deadLinks.map { $0.0 }.prefix(5).joined(separator: "\n    ")
            let moreText = deadLinks.count > 5 ? "\n    ... and \(deadLinks.count - 5) more" : ""

            issues.append(AuditIssue(
                title: "\(deadLinks.count) broken symlink(s) in developer directories",
                description: "Broken links found:\n    \(linkList)\(moreText)\n\nRemove with: find ~/Developer -type l ! -exec test -e {} \\; -print -delete",
                reclaimableMB: nil,
                severity: deadLinks.count > 20 ? .warning : .info,
                category: .symlinks,
                path: nil
            ))
        }

        return issues
    }

    // MARK: - Xcode Toolchains

    /// Check for old Xcode toolchains that are no longer needed.
    private func scanXcodeToolchains() -> [AuditIssue] {
        var issues: [AuditIssue] = []

        let toolchainsPath = NSString(string: "/Library/Developer/Toolchains").expandingTildeInPath
        guard fileManager.fileExists(atPath: toolchainsPath) else { return issues }

        let contents = (try? fileManager.contentsOfDirectory(atPath: toolchainsPath)) ?? []
        // Filter out the Xcode default toolchain
        let customToolchains = contents.filter {
            !$0.hasPrefix("XcodeDefault") && !$0.hasPrefix("xcode")
        }

        if !customToolchains.isEmpty {
            var totalSize: Double = 0
            for toolchain in customToolchains {
                let path = (toolchainsPath as NSString).appendingPathComponent(toolchain)
                totalSize += directorySizeMB(at: path)
            }

            issues.append(AuditIssue(
                title: "\(customToolchains.count) custom Xcode toolchain(s) installed",
                description: "Toolchains: \(customToolchains.joined(separator: ", ")). Remove from /Library/Developer/Toolchains if no longer needed.",
                reclaimableMB: totalSize,
                severity: .info,
                category: .toolchains,
                path: toolchainsPath
            ))
        }

        // Also check user-level toolchains
        let userToolchainsPath = NSString(string: "~/Library/Developer/Toolchains").expandingTildeInPath
        if fileManager.fileExists(atPath: userToolchainsPath) {
            let contents = (try? fileManager.contentsOfDirectory(atPath: userToolchainsPath)) ?? []
            let customToolchains = contents.filter {
                !$0.hasPrefix("XcodeDefault") && !$0.hasPrefix("xcode")
            }

            if !customToolchains.isEmpty {
                var totalSize: Double = 0
                for toolchain in customToolchains {
                    let path = (userToolchainsPath as NSString).appendingPathComponent(toolchain)
                    totalSize += directorySizeMB(at: path)
                }

                issues.append(AuditIssue(
                    title: "\(customToolchains.count) custom toolchain(s) in user Library",
                    description: "Toolchains: \(customToolchains.joined(separator: ", ")). Remove from ~/Library/Developer/Toolchains if no longer needed.",
                    reclaimableMB: totalSize,
                    severity: .info,
                    category: .toolchains,
                    path: userToolchainsPath
                ))
            }
        }

        return issues
    }

    // MARK: - Helpers

    private func directorySizeMB(at path: String) -> Double {
        guard fileManager.fileExists(atPath: path) else { return 0 }
        let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        )

        var total: UInt64 = 0
        while let item = enumerator?.nextObject() as? URL {
            if let size = try? item.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                total += UInt64(size)
            }
        }
        return Double(total) / (1024 * 1024)
    }

    private func formatSize(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }
}
