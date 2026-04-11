//
//  InstallerCleanupService.swift
//  Pulse
//
//  Scans ~/Downloads, ~/Desktop, ~/Documents, and iCloud Drive for old installer files
//  (.dmg, .pkg, .zip, .sitx, .tgz, .tar.gz) older than 7 days.
//  Also scans Homebrew cache for old cask downloads.
//  Uses FileManager.default.trashItem() for safe, recoverable deletion.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Installer File Model

struct InstallerFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let path: String
    let name: String
    let sizeBytes: UInt64
    let modificationDate: Date
    let installerType: InstallerType
    let ageDays: Int

    var sizeMB: Double { Double(sizeBytes) / (1024 * 1024) }

    var formattedSize: String {
        if sizeMB >= 1024 {
            return String(format: "%.1f GB", sizeMB / 1024)
        }
        return String(format: "%.1f MB", sizeMB)
    }

    var formattedAge: String {
        if ageDays == 0 { return "Today" }
        if ageDays == 1 { return "1 day ago" }
        return "\(ageDays) days ago"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: modificationDate)
    }

    var parentDirectory: String {
        url.deletingLastPathComponent().lastPathComponent
    }

    static func == (lhs: InstallerFile, rhs: InstallerFile) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Installer Type

enum InstallerType: String, Codable, CaseIterable, Identifiable {
    case diskImage = "DMG"
    case package = "PKG"
    case zipArchive = "ZIP"
    case stuffit = "SITX"
    case tarball = "TGZ"
    case brewCask = "Homebrew Cask"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .diskImage: return "cd"
        case .package: return "shippingbox"
        case .zipArchive: return "archivebox"
        case .stuffit: return "archivebox"
        case .tarball: return "archivebox"
        case .brewCask: return "cup.and.saucer"
        }
    }

    var colorValue: Color {
        switch self {
        case .diskImage: return .blue
        case .package: return .orange
        case .zipArchive: return .purple
        case .stuffit: return .gray
        case .tarball: return .green
        case .brewCask: return .brown
        }
    }

    var extensions: [String] {
        switch self {
        case .diskImage: return ["dmg"]
        case .package: return ["pkg"]
        case .zipArchive: return ["zip"]
        case .stuffit: return ["sitx"]
        case .tarball: return ["tgz", "tar.gz"]
        case .brewCask: return []
        }
    }
}

// MARK: - Installer Group

struct InstallerGroup: Identifiable {
    let id: UUID
    let type: InstallerType
    let ageCategory: AgeCategory
    var files: [InstallerFile]

    var totalSizeBytes: UInt64 {
        files.reduce(0) { $0 + $1.sizeBytes }
    }

    var totalSizeMB: Double { Double(totalSizeBytes) / (1024 * 1024) }

    var formattedTotalSize: String {
        let mb = totalSizeMB
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Age Category

enum AgeCategory: String, CaseIterable, Comparable {
    case week = "1-2 weeks old"
    case month = "2-4 weeks old"
    case older = "1+ months old"

    var sortOrder: Int {
        switch self {
        case .week: return 0
        case .month: return 1
        case .older: return 2
        }
    }

    static func < (lhs: AgeCategory, rhs: AgeCategory) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }
}

// MARK: - InstallerCleanupService

/// Scans for old installer files and Homebrew cask downloads that can be safely trashed.
class InstallerCleanupService: ObservableObject {
    static let shared = InstallerCleanupService()

    // MARK: - Published Properties

    @Published var installerFiles: [InstallerFile] = []
    @Published var groupedFiles: [InstallerGroup] = []
    @Published var isScanning: Bool = false
    @Published var totalReclaimableBytes: UInt64 = 0
    @Published var selectedForDeletion: Set<UUID> = []
    @Published var scanStatus: String = "Ready to scan"

    // MARK: - Configuration

    /// Minimum age in days before an installer is considered for cleanup
    var minimumAgeDays: Int = 7

    /// Scan directories for installer files
    var scanDirectories: [String] = [
        "~/Downloads",
        "~/Desktop",
        "~/Documents"
    ]

    /// Whether to scan iCloud Drive
    var scanICloudDrive: Bool = true

    /// Whether to scan Homebrew cache
    var shouldScanHomebrewCache: Bool = true

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var scanCancelled = false

    init() {}

    // MARK: - Public Methods

    /// Start scanning for old installer files
    func startScan() {
        guard !isScanning else { return }

        isScanning = true
        installerFiles = []
        groupedFiles = []
        selectedForDeletion = []
        totalReclaimableBytes = 0

        let startTime = Date()
        scanCancelled = false

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var foundFiles: [InstallerFile] = []

            // Phase 1: Scan user directories for installer files
            DispatchQueue.main.async { self.scanStatus = "Scanning user directories..." }

            for directory in self.scanDirectories {
                guard !self.scanCancelled else { break }

                let expandedPath = (directory as NSString).expandingTildeInPath
                let files = self.scanDirectoryForInstallers(expandedPath)
                foundFiles.append(contentsOf: files)
            }

            // Phase 2: Scan iCloud Drive
            if self.scanICloudDrive {
                guard !self.scanCancelled else { return }
                DispatchQueue.main.async { self.scanStatus = "Scanning iCloud Drive..." }

                if let iCloudURL = self.fileManager.url(forUbiquityContainerIdentifier: nil)?.appendingPathComponent("Documents") {
                    let files = self.scanDirectoryForInstallers(iCloudURL.path)
                    foundFiles.append(contentsOf: files)
                }
            }

            // Phase 3: Scan Homebrew cache
            if self.shouldScanHomebrewCache {
                guard !self.scanCancelled else { return }
                DispatchQueue.main.async { self.scanStatus = "Scanning Homebrew cache..." }

                let brewFiles = self.scanHomebrewCache()
                foundFiles.append(contentsOf: brewFiles)
            }

            guard !self.scanCancelled else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanStatus = "Scan cancelled"
                }
                return
            }

            // Phase 4: Filter by age
            let cutoffDate = Calendar.current.date(
                byAdding: .day,
                value: -self.minimumAgeDays,
                to: Date()
            ) ?? Date.distantPast

            var oldFiles = foundFiles.filter { $0.modificationDate < cutoffDate }

            // Sort by age descending (oldest first)
            oldFiles.sort { $0.modificationDate < $1.modificationDate }

            // Phase 5: Group files
            var groups: [InstallerGroup] = []
            for type in InstallerType.allCases {
                for ageCat in AgeCategory.allCases.sorted() {
                    let typeFiles = oldFiles.filter { file in
                        let matchesType = self.fileMatchesType(file, type: type)
                        let matchesAge = self.fileAgeCategory(file) == ageCat
                        return matchesType && matchesAge
                    }

                    if !typeFiles.isEmpty {
                        groups.append(InstallerGroup(
                            id: UUID(),
                            type: type,
                            ageCategory: ageCat,
                            files: typeFiles
                        ))
                    }
                }
            }

            let totalSize = oldFiles.reduce(UInt64(0)) { $0 + $1.sizeBytes }
            let duration = Date().timeIntervalSince(startTime)

            DispatchQueue.main.async {
                self.installerFiles = oldFiles
                self.groupedFiles = groups
                self.totalReclaimableBytes = totalSize
                self.isScanning = false
                self.scanStatus = "Found \(oldFiles.count) installers (\(String(format: "%.1f", Double(totalSize) / (1024*1024)))MB)"
                print("[InstallerCleanupService] Scan complete: \(oldFiles.count) files in \(String(format: "%.1f", duration))s")
            }
        }
    }

    /// Cancel ongoing scan
    func cancelScan() {
        scanCancelled = true
        isScanning = false
        scanStatus = "Scan cancelled"
    }

    /// Select all files for deletion
    func selectAll() {
        selectedForDeletion = Set(installerFiles.map { $0.id })
    }

    /// Deselect all files
    func deselectAll() {
        selectedForDeletion = []
    }

    /// Calculate selected reclaimable space
    var selectedReclaimableBytes: UInt64 {
        installerFiles
            .filter { selectedForDeletion.contains($0.id) }
            .reduce(UInt64(0)) { $0 + $1.sizeBytes }
    }

    /// Delete selected installer files (move to trash)
    func deleteSelectedFiles() -> (success: Int, failed: Int, bytesFreed: UInt64) {
        var success = 0
        var failed = 0
        var bytesFreed: UInt64 = 0

        let idsToDelete = selectedForDeletion

        for file in installerFiles.reversed() {
            if idsToDelete.contains(file.id) {
                do {
                    try fileManager.trashItem(at: file.url, resultingItemURL: nil)
                    success += 1
                    bytesFreed += file.sizeBytes
                    print("[InstallerCleanupService] Moved to trash: \(file.path)")
                } catch {
                    print("[InstallerCleanupService] Failed to trash \(file.path): \(error.localizedDescription)")
                    failed += 1
                }
            }
        }

        // Remove deleted files
        installerFiles.removeAll { idsToDelete.contains($0.id) }

        // Rebuild groups
        rebuildGroups()

        selectedForDeletion.removeAll()

        return (success, failed, bytesFreed)
    }

    // MARK: - Private Methods

    private func scanDirectoryForInstallers(_ directory: String) -> [InstallerFile] {
        var files: [InstallerFile] = []

        let installerExtensions = ["dmg", "pkg", "zip", "sitx", "tgz"]

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: directory),
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isRegularFileKey,
                .isSymbolicLinkKey
            ],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        while let item = enumerator.nextObject() as? URL {
            let ext = item.pathExtension.lowercased()
            guard installerExtensions.contains(ext) else { continue }

            do {
                let resourceValues = try item.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isRegularFileKey,
                    .isSymbolicLinkKey
                ])

                guard resourceValues.isRegularFile == true else { continue }
                if let isSymlink = resourceValues.isSymbolicLink, isSymlink { continue }
                guard let fileSize = resourceValues.fileSize else { continue }
                guard let modDate = resourceValues.contentModificationDate else { continue }

                let installerType = typeFromExtension(ext)
                let ageDays = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0

                let file = InstallerFile(
                    id: UUID(),
                    url: item,
                    path: item.path,
                    name: item.lastPathComponent,
                    sizeBytes: UInt64(fileSize),
                    modificationDate: modDate,
                    installerType: installerType,
                    ageDays: ageDays
                )
                files.append(file)
            } catch {
                continue
            }
        }

        return files
    }

    private func scanHomebrewCache() -> [InstallerFile] {
        var files: [InstallerFile] = []

        // Homebrew cache location
        let brewCachePath = (("~/Library/Caches/Homebrew") as NSString).expandingTildeInPath
        let brewCacheURL = URL(fileURLWithPath: brewCachePath)

        guard fileManager.fileExists(atPath: brewCachePath) else { return [] }

        // Homebrew cask downloads are typically .zip, .dmg, .tar.gz files
        let caskExtensions = ["zip", "dmg", "tar.gz", "tgz"]

        guard let enumerator = fileManager.enumerator(
            at: brewCacheURL,
            includingPropertiesForKeys: [
                .fileSizeKey,
                .contentModificationDateKey,
                .isRegularFileKey
            ],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        while let item = enumerator.nextObject() as? URL {
            let ext = item.pathExtension.lowercased()
            let fullPath = item.path.lowercased()

            // Check for cask-related files
            let isCaskFile = caskExtensions.contains(ext) ||
                fullPath.contains("--") // Homebrew cask naming convention

            guard isCaskFile else { continue }

            do {
                let resourceValues = try item.resourceValues(forKeys: [
                    .fileSizeKey,
                    .contentModificationDateKey,
                    .isRegularFileKey
                ])

                guard resourceValues.isRegularFile == true else { continue }
                guard let fileSize = resourceValues.fileSize, fileSize > 0 else { continue }
                guard let modDate = resourceValues.contentModificationDate else { continue }

                let ageDays = Calendar.current.dateComponents([.day], from: modDate, to: Date()).day ?? 0

                let file = InstallerFile(
                    id: UUID(),
                    url: item,
                    path: item.path,
                    name: item.lastPathComponent,
                    sizeBytes: UInt64(fileSize),
                    modificationDate: modDate,
                    installerType: .brewCask,
                    ageDays: ageDays
                )
                files.append(file)
            } catch {
                continue
            }
        }

        return files
    }

    private func typeFromExtension(_ ext: String) -> InstallerType {
        switch ext {
        case "dmg": return .diskImage
        case "pkg": return .package
        case "zip": return .zipArchive
        case "sitx": return .stuffit
        case "tgz": return .tarball
        default: return .zipArchive
        }
    }

    private func fileMatchesType(_ file: InstallerFile, type: InstallerType) -> Bool {
        switch type {
        case .diskImage: return file.installerType == .diskImage
        case .package: return file.installerType == .package
        case .zipArchive: return file.installerType == .zipArchive
        case .stuffit: return file.installerType == .stuffit
        case .tarball: return file.installerType == .tarball
        case .brewCask: return file.installerType == .brewCask
        }
    }

    private func fileAgeCategory(_ file: InstallerFile) -> AgeCategory {
        let days = file.ageDays
        if days >= 30 { return .older }
        if days >= 14 { return .month }
        return .week
    }

    private func rebuildGroups() {
        var groups: [InstallerGroup] = []
        for type in InstallerType.allCases {
            for ageCat in AgeCategory.allCases.sorted() {
                let typeFiles = installerFiles.filter { file in
                    fileMatchesType(file, type: type) && fileAgeCategory(file) == ageCat
                }
                if !typeFiles.isEmpty {
                    groups.append(InstallerGroup(
                        id: UUID(),
                        type: type,
                        ageCategory: ageCat,
                        files: typeFiles
                    ))
                }
            }
        }
        groupedFiles = groups
        totalReclaimableBytes = installerFiles.reduce(UInt64(0)) { $0 + $1.sizeBytes }
    }
}
