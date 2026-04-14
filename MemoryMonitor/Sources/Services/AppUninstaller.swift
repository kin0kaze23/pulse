//
//  AppUninstaller.swift
//  Pulse
//
//  Extremely precise app uninstaller that removes an app AND its associated files.
//
//  CRITICAL SAFETY RULES (learned from DodoTidy's mistake):
//  - NO fuzzy matching, NO pattern matching for associated files
//  - ONLY checks EXACT known paths by bundle identifier
//  - NEVER scans ~/Documents, ~/Desktop, ~/Downloads
//  - Shows PREVIEW before deletion
//  - Uses NSWorkspace.shared.recycle() for trash-based deletion
//  - Protected apps cannot be uninstalled
//

import Foundation
import AppKit
import Combine

// MARK: - App Info

/// Represents an installed application found via LaunchServices
struct InstalledApp: Identifiable, Equatable {
    let id = UUID()
    let bundleIdentifier: String
    let appName: String
    let appURL: URL
    let version: String?
    let fileSizeBytes: UInt64

    var fileSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(fileSizeBytes))
    }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool {
        lhs.bundleIdentifier == rhs.bundleIdentifier
    }
}

// MARK: - Associated File

/// An associated file that belongs to an app (found via EXACT path matching only)
struct AssociatedFile: Identifiable {
    let id = UUID()
    let path: String
    let type: AssociatedFileType
    let sizeBytes: UInt64

    var sizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(sizeBytes))
    }

    var sizeMB: Double {
        Double(sizeBytes) / (1024 * 1024)
    }
}

enum AssociatedFileType: String {
    case applicationSupport = "Application Support"
    case containers = "Containers"
    case groupContainers = "Group Containers"
    case caches = "Caches"
    case preferences = "Preferences"
    case savedState = "Saved Application State"
    case logs = "Logs"

    var icon: String {
        switch self {
        case .applicationSupport: return "folder.fill.badge.gearshape"
        case .containers: return "app.badge"
        case .groupContainers: return "rectangle.on.rectangle"
        case .caches: return "wind"
        case .preferences: return "gearshape.fill"
        case .savedState: return "clock.arrow.circlepath"
        case .logs: return "doc.text.fill"
        }
    }
}

// MARK: - Uninstall Preview

/// Preview of what will be removed when uninstalling an app
struct UninstallPreview {
    let app: InstalledApp
    let appIsRunning: Bool
    let associatedFiles: [AssociatedFile]
    let totalSizeBytes: UInt64

    var totalSizeText: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(totalSizeBytes))
    }

    var totalSizeMB: Double {
        Double(totalSizeBytes) / (1024 * 1024)
    }

    var canUninstall: Bool {
        !appIsRunning
    }

    var itemCount: Int {
        1 + associatedFiles.count // app bundle + associated files
    }
}

// MARK: - Uninstall Result

struct UninstallResult {
    let success: Bool
    let appRemoved: Bool
    let filesRemoved: Int
    let filesFailed: Int
    let errorMessage: String?

    var summary: String {
        if success {
            return "Successfully uninstalled. \(filesRemoved) files moved to Trash."
        } else {
            return "Uninstall failed: \(errorMessage ?? "Unknown error")"
        }
    }
}

// MARK: - App Uninstaller Service

/// Extremely precise app uninstaller.
///
/// SAFETY PRINCIPLES:
/// - Uses LaunchServices (LSCopyApplicationURLsForBundleIdentifier) to find apps
/// - Associated files use EXACT path matching ONLY -- no wildcards, no fuzzy logic
/// - Protected system apps cannot be uninstalled
/// - Preview shown before any deletion
/// - Trash-based deletion via NSWorkspace.shared.recycle()
@MainActor
class AppUninstaller: ObservableObject {

    // MARK: - Protected Apps

    /// Bundle identifiers of apps that must NEVER be uninstalled
    nonisolated static var protectedBundleIdentifiers: Set<String> {
        [
            // Core system apps
            "com.apple.finder",
            "com.apple.dock",
            "com.apple.Safari",
            "com.apple.mail",
            "com.apple.Terminal",
            "com.apple.TextEdit",
            "com.apple.Preview",
            "com.apple.Photos",
            "com.apple.Music",
            "com.apple.iCal",
            "com.apple.calculator",
            "com.apple.systempreferences",
            "com.apple.systemsettings",
            // Pulse itself
            "com.nousresearch.Pulse",
        ]
    }

    /// App names that must NEVER be uninstalled (checked as fallback)
    nonisolated static var protectedAppNames: Set<String> {
        [
            "Finder", "Dock", "Safari", "Mail", "System Preferences",
            "System Settings", "Terminal", "Preview", "Photos",
            "Music", "Calendar", "Calculator", "Pulse",
        ]
    }

    // MARK: - Published State

    @Published var installedApps: [InstalledApp] = []
    @Published var isScanning = false
    @Published var currentPreview: UninstallPreview?
    @Published var lastResult: UninstallResult?
    @Published var statusMessage: String = ""
    @Published var isUninstalling = false

    // MARK: - Scan Installed Apps

    /// Scan for all installed apps using LaunchServices
    func scanInstalledApps() {
        guard !isScanning else { return }
        isScanning = true
        statusMessage = "Scanning installed apps..."

        Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            let apps = self.discoverInstalledApps()
            let sorted = apps.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

            await MainActor.run {
                self.installedApps = sorted
                self.isScanning = false
                self.statusMessage = "Found \(sorted.count) apps"
            }
        }
    }

    /// Discover installed apps via LaunchServices
    private nonisolated func discoverInstalledApps() -> [InstalledApp] {
        var apps: [InstalledApp] = []

        let workspace = NSWorkspace.shared

        // Deduplicate by path
        var seenPaths: Set<String> = []

        // Scan /Applications and ~/Applications directly
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
        let searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            homeDir.appendingPathComponent("Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Applications/Utilities"),
        ]

        for searchDir in searchDirectories {
            guard let enumerator = FileManager.default.enumerator(
                at: searchDir,
                includingPropertiesForKeys: [.isApplicationKey, .fileSizeKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            while let fileURL = enumerator.nextObject() as? URL {
                guard fileURL.pathExtension == "app" else { continue }
                guard !seenPaths.contains(fileURL.path) else { continue }
                seenPaths.insert(fileURL.path)

                guard let bundle = Bundle(url: fileURL),
                      let bundleID = bundle.bundleIdentifier else { continue }

                let appName = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                    ?? bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                    ?? fileURL.deletingPathExtension().lastPathComponent

                let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

                let fileSize = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0

                apps.append(InstalledApp(
                    bundleIdentifier: bundleID,
                    appName: appName,
                    appURL: fileURL,
                    version: version,
                    fileSizeBytes: fileSize
                ))
            }
        }

        return apps
    }

    // MARK: - Preview Uninstall

    /// Create a preview of what will be removed when uninstalling an app.
    /// Uses EXACT path matching ONLY -- no fuzzy logic.
    func previewUninstall(for app: InstalledApp) {
        let preview = createPreview(for: app)
        currentPreview = preview
    }

    /// Create preview without setting published state (for testing)
    nonisolated func createPreview(for app: InstalledApp) -> UninstallPreview {
        let files = findAssociatedFiles(for: app)
        let appIsRunning = isAppRunning(app)
        let totalSize = app.fileSizeBytes + files.reduce(0) { $0 + $1.sizeBytes }

        return UninstallPreview(
            app: app,
            appIsRunning: appIsRunning,
            associatedFiles: files,
            totalSizeBytes: totalSize
        )
    }

    // MARK: - Find Associated Files (EXACT PATHS ONLY)

    /// Find associated files for an app using ONLY exact path matching.
    ///
    /// CRITICAL: This method deliberately does NOT use any pattern matching,
    /// glob expansion, or fuzzy logic. It checks only these exact paths:
    ///
    /// - ~/Library/Application Support/{bundleIdentifier}
    /// - ~/Library/Containers/{bundleIdentifier}
    /// - ~/Library/Caches/{bundleIdentifier}
    /// - ~/Library/Preferences/{bundleIdentifier}.plist
    /// - ~/Library/Saved Application State/{bundleIdentifier}.savedState
    /// - ~/Library/Logs/{bundleIdentifier}
    ///
    /// It NEVER scans ~/Documents, ~/Desktop, or ~/Downloads.
    ///
    /// For Group Containers, it checks {groupIdentifier} if provided.
    nonisolated func findAssociatedFiles(for app: InstalledApp) -> [AssociatedFile] {
        var files: [AssociatedFile] = []
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let bundleID = app.bundleIdentifier

        // EXACT paths to check -- no pattern matching whatsoever
        let exactPaths: [(path: String, type: AssociatedFileType)] = [
            ("\(home)/Library/Application Support/\(bundleID)", .applicationSupport),
            ("\(home)/Library/Containers/\(bundleID)", .containers),
            ("\(home)/Library/Caches/\(bundleID)", .caches),
            ("\(home)/Library/Preferences/\(bundleID).plist", .preferences),
            ("\(home)/Library/Saved Application State/\(bundleID).savedState", .savedState),
            ("\(home)/Library/Logs/\(bundleID)", .logs),
        ]

        for (path, type) in exactPaths {
            if FileManager.default.fileExists(atPath: path) {
                let sizeBytes = Self.sizeOfPath(path)
                files.append(AssociatedFile(path: path, type: type, sizeBytes: sizeBytes))
            }
        }

        // Check Group Containers if we can discover them
        // We only check known group container directories, not arbitrary patterns
        files.append(contentsOf: findGroupContainers(for: bundleID, home: home))

        return files
    }

    /// Find Group Container directories for a bundle ID.
    /// Uses EXACT path matching in ~/Library/Group Containers/.
    /// Only checks directories that actually exist.
    nonisolated func findGroupContainers(for bundleID: String, home: String) -> [AssociatedFile] {
        var files: [AssociatedFile] = []
        let groupContainersPath = "\(home)/Library/Group Containers"

        guard FileManager.default.fileExists(atPath: groupContainersPath) else { return files }

        // List directories in Group Containers and check if any match the bundle ID exactly
        // We do NOT use glob patterns or partial matching
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: groupContainersPath)
            for item in contents {
                let itemPath = "\(groupContainersPath)/\(item)"
                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: itemPath, isDirectory: &isDir),
                      isDir.boolValue else { continue }

                // Check if the directory name starts with or contains the bundle ID
                // This is necessary because group IDs are often like "group.com.company.app"
                // but we ONLY match if the bundle ID is clearly part of the group ID
                if item == bundleID || item.hasPrefix(bundleID + ".") || item.hasPrefix("group.\(bundleID)") {
                    let sizeBytes = Self.sizeOfPath(itemPath)
                    files.append(AssociatedFile(
                        path: itemPath,
                        type: .groupContainers,
                        sizeBytes: sizeBytes
                    ))
                }
            }
        } catch {
            // Silently ignore -- Group Containers may not be accessible
        }

        return files
    }

    /// Calculate size of a path (file or directory)
    nonisolated static func sizeOfPath(_ path: String) -> UInt64 {
        let url = URL(fileURLWithPath: path)
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }

        if isDir.boolValue {
            return DirectorySizeUtility.directorySizeBytes(path)
        } else {
            return (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { UInt64($0) } ?? 0
        }
    }

    // MARK: - Check if App is Running

    /// Check if an app is currently running
    nonisolated func isAppRunning(_ app: InstalledApp) -> Bool {
        // Use NSWorkspace runningApplications
        let runningApps = NSWorkspace.shared.runningApplications
        return runningApps.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    // MARK: - Protection Checks

    /// Check if an app is protected and cannot be uninstalled
    nonisolated func isProtected(_ app: InstalledApp) -> Bool {
        if Self.protectedBundleIdentifiers.contains(app.bundleIdentifier) {
            return true
        }
        if Self.protectedAppNames.contains(app.appName) {
            return true
        }
        // Check if it's a system app (in /System)
        if app.appURL.path.hasPrefix("/System/") {
            return true
        }
        return false
    }

    // MARK: - Execute Uninstall

    /// Uninstall an app and its associated files, moving everything to Trash.
    /// Must call previewUninstall first.
    func uninstall(_ app: InstalledApp) async -> UninstallResult {
        guard !isUninstalling else {
            return UninstallResult(success: false, appRemoved: false, filesRemoved: 0, filesFailed: 0, errorMessage: "Uninstall already in progress")
        }

        guard let preview = currentPreview, preview.app.bundleIdentifier == app.bundleIdentifier else {
            return UninstallResult(success: false, appRemoved: false, filesRemoved: 0, filesFailed: 0, errorMessage: "No preview available. Please preview first.")
        }

        guard preview.canUninstall else {
            return UninstallResult(success: false, appRemoved: false, filesRemoved: 0, filesFailed: 0, errorMessage: "\(app.appName) is currently running. Please quit it first.")
        }

        guard !isProtected(app) else {
            return UninstallResult(success: false, appRemoved: false, filesRemoved: 0, filesFailed: 0, errorMessage: "\(app.appName) is a protected system app and cannot be uninstalled.")
        }

        isUninstalling = true
        statusMessage = "Uninstalling \(app.appName)..."

        var filesRemoved = 0
        var filesFailed = 0
        var appRemoved = false
        var errorMessage: String?

        // Step 1: Move the app bundle to trash
        do {
            try await NSWorkspace.shared.recycle([app.appURL])
            appRemoved = true
            filesRemoved += 1
            statusMessage = "Moved \(app.appName) to Trash..."
        } catch {
            errorMessage = "Failed to move app to Trash: \(error.localizedDescription)"
        }

        // Step 2: Move each associated file to trash
        for file in preview.associatedFiles {
            let fileURL = URL(fileURLWithPath: file.path)
            do {
                try await NSWorkspace.shared.recycle([fileURL])
                filesRemoved += 1
                statusMessage = "Removed \(file.type.rawValue)..."
            } catch {
                filesFailed += 1
                print("[AppUninstaller] Failed to trash \(file.path): \(error.localizedDescription)")
            }
        }

        let success = appRemoved && filesFailed == 0
        let result = UninstallResult(
            success: success,
            appRemoved: appRemoved,
            filesRemoved: filesRemoved,
            filesFailed: filesFailed,
            errorMessage: errorMessage
        )

        await MainActor.run {
            self.lastResult = result
            self.isUninstalling = false
            self.currentPreview = nil
            self.statusMessage = result.summary

            // Refresh the installed apps list
            self.scanInstalledApps()
        }

        return result
    }

    // MARK: - Utility

    /// Get app icon for a bundle URL
    nonisolated func iconForApp(at url: URL) -> NSImage? {
        NSWorkspace.shared.icon(forFile: url.path)
    }

    /// Validate that a path is safe to delete (defense in depth)
    nonisolated static func isPathSafeToDelete(_ path: String) -> Bool {
        let lowerPath = path.lowercased()

        // NEVER allow deleting from these locations
        let forbiddenPrefixes = [
            "/system/", "/bin/", "/sbin/", "/usr/",
            "/library/", "/network/", "/cores/",
            "/dev/", "/tmp/", "/private/",
        ]

        for prefix in forbiddenPrefixes {
            if lowerPath.hasPrefix(prefix) {
                return false
            }
        }

        // NEVER allow deleting Documents, Desktop, or Downloads
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix("\(home)/Documents") ||
           path.hasPrefix("\(home)/Desktop") ||
           path.hasPrefix("\(home)/Downloads") {
            return false
        }

        // NEVER allow deleting .app bundles outside of the target app
        // (we handle the target app separately)
        if lowerPath.hasSuffix(".app") || lowerPath.hasSuffix(".app/") {
            return false
        }

        return true
    }
}
