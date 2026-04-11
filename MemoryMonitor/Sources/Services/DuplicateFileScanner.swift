//
//  DuplicateFileScanner.swift
//  Pulse
//
//  Scans user-specified directories for duplicate files (same content hash).
//  Uses SHA256 for files > 1MB, file size + name for smaller files (fast pre-filter).
//  Groups duplicates by hash and reports total reclaimable space.
//

import Foundation
import CryptoKit
import Combine

// MARK: - Duplicate File Models

/// A single file that is part of a duplicate group
struct DuplicateFile: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let path: String
    let name: String
    let sizeBytes: UInt64
    let modificationDate: Date
    let hash: String

    var sizeMB: Double { Double(sizeBytes) / (1024 * 1024) }

    var formattedSize: String {
        if sizeMB >= 1024 {
            return String(format: "%.1f GB", sizeMB / 1024)
        }
        return String(format: "%.1f MB", sizeMB)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: modificationDate)
    }

    var parentDirectory: String {
        url.deletingLastPathComponent().path
    }

    static func == (lhs: DuplicateFile, rhs: DuplicateFile) -> Bool {
        lhs.id == rhs.id
    }
}

/// A group of duplicate files sharing the same content
struct DuplicateGroup: Identifiable {
    let id: UUID
    let hash: String
    let fileSizeBytes: UInt64
    var files: [DuplicateFile]

    /// Number of extra copies (total - 1)
    var duplicateCount: Int { max(0, files.count - 1) }

    /// Space reclaimable if we delete all but one copy
    var reclaimableBytes: UInt64 {
        UInt64(duplicateCount) * fileSizeBytes
    }

    var reclaimableMB: Double { Double(reclaimableBytes) / (1024 * 1024) }

    var formattedReclaimable: String {
        let mb = reclaimableMB
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }

    var formattedFileSize: String {
        let mb = Double(fileSizeBytes) / (1024 * 1024)
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.1f MB", mb)
    }
}

// MARK: - Scan Progress

enum DuplicateScanProgress: Equatable {
    case idle
    case preparing(directories: [String])
    case enumerating(currentDirectory: String, fileCount: Int)
    case hashing(filesProcessed: Int, totalCandidates: Int)
    case completed(groups: Int, totalDuplicates: Int)
    case failed(error: String)

    var statusText: String {
        switch self {
        case .idle:
            return "Ready to scan"
        case .preparing:
            return "Preparing scan..."
        case .enumerating(let dir, let count):
            return "Enumerating: \(count) files in \(dir)"
        case .hashing(let processed, let total):
            return "Hashing: \(processed)/\(total) files"
        case .completed(let groups, let dups):
            return "Found \(groups) duplicate groups (\(dups) extra copies)"
        case .failed(let error):
            return "Scan failed: \(error)"
        }
    }
}

// MARK: - DuplicateFileScanner

/// Scans directories for duplicate files using content hashing.
/// Uses SHA256 for files > 1MB, fast pre-filter (size + name) for smaller files.
class DuplicateFileScanner: ObservableObject {
    static let shared = DuplicateFileScanner()

    // MARK: - Published Properties

    @Published var duplicateGroups: [DuplicateGroup] = []
    @Published var scanProgress: DuplicateScanProgress = .idle
    @Published var isScanning: Bool = false
    @Published var totalReclaimableBytes: UInt64 = 0
    @Published var selectedForDeletion: Set<UUID> = []

    // MARK: - Configuration

    /// Minimum file size in bytes to use full SHA256 hashing (default: 1MB)
    var sha256Threshold: UInt64 = 1 * 1024 * 1024

    /// Directories to scan (default: empty, user must add)
    var directoriesToScan: [String] = []

    /// Maximum number of duplicate groups to report
    var maxGroups: Int = 5000

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private let scanQueue = DispatchQueue(label: "com.pulse.duplicatescanner", qos: .userInitiated)
    private var scanTask: DispatchWorkItem?
    private var scanCancelled = false

    // MARK: - Protected Paths (never suggest deletion)

    static let protectedPaths = [
        "/Documents",
        "/Desktop",
        "/Library/Preferences",
        "/.ssh",
        "/.gnupg"
    ]

    init() {}

    // MARK: - Public Methods

    /// Start scanning for duplicate files
    func startScan(directories: [String]? = nil) {
        guard !isScanning else { return }

        let dirs = directories ?? directoriesToScan
        guard !dirs.isEmpty else {
            scanProgress = .failed(error: "No directories specified")
            return
        }

        // Validate directories exist
        let validDirs = dirs.filter { fileManager.fileExists(atPath: ($0 as NSString).expandingTildeInPath) }
        guard !validDirs.isEmpty else {
            scanProgress = .failed(error: "No valid directories found")
            return
        }

        isScanning = true
        duplicateGroups = []
        selectedForDeletion = []
        totalReclaimableBytes = 0
        scanProgress = .preparing(directories: validDirs)

        let startTime = Date()
        scanCancelled = false

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            // Phase 1: Enumerate all files, collect by size+name (fast pre-filter)
            DispatchQueue.main.async {
                self.scanProgress = .enumerating(currentDirectory: "starting...", fileCount: 0)
            }

            var sizeNameGroups: [String: [URL]] = [:]
            var fileCount = 0

            for directory in validDirs {
                guard !scanCancelled else { break }

                let expandedPath = (directory as NSString).expandingTildeInPath
                DispatchQueue.main.async {
                    self.scanProgress = .enumerating(currentDirectory: directory, fileCount: fileCount)
                }

                guard let enumerator = self.fileManager.enumerator(
                    at: URL(fileURLWithPath: expandedPath),
                    includingPropertiesForKeys: [
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey
                    ],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                ) else { continue }

                while let item = enumerator.nextObject() as? URL {
                    guard !scanCancelled else { break }

                    do {
                        let resourceValues = try item.resourceValues(forKeys: [
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .isRegularFileKey,
                            .isSymbolicLinkKey
                        ])

                        guard resourceValues.isRegularFile == true else { continue }
                        guard let fileSize = resourceValues.fileSize, fileSize > 0 else { continue }

                        // Skip symlinks
                        if let isSymlink = resourceValues.isSymbolicLink, isSymlink { continue }

                        fileCount += 1

                        // Fast pre-filter: group by size + name
                        let key = "\(fileSize)_\(item.lastPathComponent.lowercased())"
                        sizeNameGroups[key, default: []].append(item)
                    } catch {
                        continue
                    }
                }
            }

            guard !scanCancelled else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanProgress = .idle
                }
                return
            }

            // Phase 2: Only keep groups with 2+ files (potential duplicates)
            let candidates = sizeNameGroups.values.filter { $0.count > 1 }.flatMap { $0 }

            guard !candidates.isEmpty else {
                let duration = Date().timeIntervalSince(startTime)
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanProgress = .completed(groups: 0, totalDuplicates: 0)
                    print("[DuplicateFileScanner] No potential duplicates found in \(String(format: "%.1f", duration))s")
                }
                return
            }

            // Phase 3: Hash candidate files
            var hashGroups: [String: [DuplicateFile]] = [:]
            var filesProcessed = 0

            DispatchQueue.main.async {
                self.scanProgress = .hashing(filesProcessed: 0, totalCandidates: candidates.count)
            }

            for url in candidates {
                guard !scanCancelled else { break }

                do {
                    let resourceValues = try url.resourceValues(forKeys: [
                        .fileSizeKey,
                        .contentModificationDateKey
                    ])

                    guard let fileSize = resourceValues.fileSize,
                          let modDate = resourceValues.contentModificationDate else { continue }

                    let hash = try self.sha256Hash(of: url)

                    let dupFile = DuplicateFile(
                        id: UUID(),
                        url: url,
                        path: url.path,
                        name: url.lastPathComponent,
                        sizeBytes: UInt64(fileSize),
                        modificationDate: modDate,
                        hash: hash
                    )

                    hashGroups[hash, default: []].append(dupFile)
                    filesProcessed += 1

                    if filesProcessed % 100 == 0 {
                        DispatchQueue.main.async {
                            self.scanProgress = .hashing(filesProcessed: filesProcessed, totalCandidates: candidates.count)
                        }
                    }
                } catch {
                    continue
                }
            }

            guard !scanCancelled else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanProgress = .idle
                }
                return
            }

            // Phase 4: Build duplicate groups (only groups with 2+ files)
            var groups: [DuplicateGroup] = []
            for (hash, files) in hashGroups where files.count > 1 {
                let group = DuplicateGroup(
                    id: UUID(),
                    hash: hash,
                    fileSizeBytes: files.first!.sizeBytes,
                    files: files
                )
                groups.append(group)

                if groups.count >= self.maxGroups { break }
            }

            // Sort groups by reclaimable space descending
            groups.sort { $0.reclaimableBytes > $1.reclaimableBytes }

            let totalReclaimable = groups.reduce(UInt64(0)) { $0 + $1.reclaimableBytes }
            let totalDuplicates = groups.reduce(0) { $0 + $1.duplicateCount }
            let duration = Date().timeIntervalSince(startTime)

            DispatchQueue.main.async {
                self.duplicateGroups = groups
                self.totalReclaimableBytes = totalReclaimable
                self.isScanning = false
                self.scanProgress = .completed(groups: groups.count, totalDuplicates: totalDuplicates)
                print("[DuplicateFileScanner] Scan complete: \(groups.count) groups, \(totalReclaimable / (1024*1024))MB reclaimable in \(String(format: "%.1f", duration))s")
            }
        }

        scanTask = workItem
        scanQueue.async(execute: workItem)
    }

    /// Cancel ongoing scan
    func cancelScan() {
        scanCancelled = true
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = .idle
    }

    /// Check if a file path is in a protected directory
    static func isPathProtected(_ path: String) -> Bool {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path

        for protected in protectedPaths {
            let protectedFullPath = homeDir + protected
            if path.hasPrefix(protectedFullPath) {
                return true
            }
        }
        return false
    }

    /// Check if a file is safe to delete (not in protected paths)
    func isFileSafeToDelete(_ file: DuplicateFile) -> Bool {
        return !Self.isPathProtected(file.path)
    }

    /// Auto-select duplicates for deletion, keeping the oldest file
    func autoSelectOldestKeep() {
        selectedForDeletion = []
        for group in duplicateGroups {
            // Sort by modification date, keep oldest
            let sorted = group.files.sorted { $0.modificationDate < $1.modificationDate }
            for file in sorted.dropFirst() {
                if isFileSafeToDelete(file) {
                    selectedForDeletion.insert(file.id)
                }
            }
        }
    }

    /// Auto-select duplicates for deletion, keeping the newest file
    func autoSelectNewestKeep() {
        selectedForDeletion = []
        for group in duplicateGroups {
            // Sort by modification date descending, keep newest
            let sorted = group.files.sorted { $0.modificationDate > $1.modificationDate }
            for file in sorted.dropFirst() {
                if isFileSafeToDelete(file) {
                    selectedForDeletion.insert(file.id)
                }
            }
        }
    }

    /// Calculate reclaimable space for currently selected files
    var selectedReclaimableBytes: UInt64 {
        var total: UInt64 = 0
        for group in duplicateGroups {
            let selectedInGroup = group.files.filter { selectedForDeletion.contains($0.id) }
            // We can only reclaim if at least one file is kept
            let unselectedCount = group.files.count - selectedInGroup.count
            if unselectedCount >= 1 {
                total += UInt64(selectedInGroup.count) * group.fileSizeBytes
            }
        }
        return total
    }

    /// Delete selected duplicate files (move to trash)
    func deleteSelectedFiles() -> (success: Int, failed: Int, bytesFreed: UInt64) {
        var success = 0
        var failed = 0
        var bytesFreed: UInt64 = 0

        for groupIndex in duplicateGroups.indices {
            var group = duplicateGroups[groupIndex]
            group.files.removeAll { file in
                if selectedForDeletion.contains(file.id) {
                    do {
                        try fileManager.trashItem(at: file.url, resultingItemURL: nil)
                        success += 1
                        bytesFreed += file.sizeBytes
                        print("[DuplicateFileScanner] Moved to trash: \(file.path)")
                        return true
                    } catch {
                        print("[DuplicateFileScanner] Failed to trash \(file.path): \(error.localizedDescription)")
                        failed += 1
                        return false
                    }
                }
                return false
            }
            duplicateGroups[groupIndex] = group
        }

        // Remove empty groups
        duplicateGroups.removeAll { $0.files.count < 2 }

        // Recalculate totals
        totalReclaimableBytes = duplicateGroups.reduce(UInt64(0)) { $0 + $1.reclaimableBytes }
        selectedForDeletion.removeAll()

        return (success, failed, bytesFreed)
    }
}

// MARK: - SHA256 Hashing Extension

extension DuplicateFileScanner {
    /// Compute SHA256 hash of a file's contents
    private func sha256Hash(of url: URL) throws -> String {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
}
