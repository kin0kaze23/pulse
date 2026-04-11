import Foundation
import AppKit

/// Service to scan directories for large files
class LargeFileFinder: ObservableObject {
    static let shared = LargeFileFinder()

    // MARK: - Published Properties

    @Published private(set) var scanResults: [LargeFileScanResult] = []
    @Published private(set) var scanProgress: ScanProgress = .idle
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanStatistics: ScanStatistics?

    // MARK: - Configuration

    var configuration: ScanConfiguration {
        didSet {
            // Add protected paths from AppSettings if available
            let settings = AppSettings.shared
            for path in settings.whitelistedPaths {
                configuration.addProtectedPath(path)
            }
        }
    }

    // MARK: - Private Properties

    private let fileManager = FileManager.default
    private var scanTask: DispatchWorkItem?
    private let scanQueue = DispatchQueue(label: "com.pulse.largefilefinder", qos: .userInitiated)

    // MARK: - Initialization

    private init() {
        self.configuration = ScanConfiguration()
    }

    // MARK: - Public Methods

    /// Start scanning for large files
    func startScan() {
        guard !isScanning else { return }

        isScanning = true
        scanResults = []
        scanProgress = .idle
        scanStatistics = nil

        let startTime = Date()
        var filesScanned = 0
        var totalSizeScanned: UInt64 = 0

        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            var largeFiles: [LargeFileScanResult] = []
            let minimumSize = UInt64(self.configuration.minimumSizeMB * 1024 * 1024)

            // Scan each directory
            for directory in self.configuration.directoriesToScan {
                guard !self.scanTask!.isCancelled else { break }

                self.scanProgress = .scanning(currentPath: directory, filesScanned: filesScanned)

                let enumerator = self.fileManager.enumerator(
                    at: URL(fileURLWithPath: directory),
                    includingPropertiesForKeys: [
                        .fileSizeKey,
                        .contentModificationDateKey,
                        .isRegularFileKey,
                        .isSymbolicLinkKey
                    ],
                    options: [
                        .skipsHiddenFiles,
                        .skipsPackageDescendants
                    ]
                )

                while let url = enumerator?.nextObject() as? URL {
                    guard !self.scanTask!.isCancelled else { break }

                    do {
                        let resourceValues = try url.resourceValues(forKeys: [
                            .fileSizeKey,
                            .contentModificationDateKey,
                            .isRegularFileKey,
                            .isSymbolicLinkKey
                        ])

                        // Skip non-regular files
                        guard resourceValues.isRegularFile == true else { continue }

                        // Skip symlinks if configured
                        if self.configuration.followSymlinks == false {
                            do {
                                let resolvedURL = try url.resolvingSymlinksInPath()
                                if url.path != resolvedURL.path {
                                    continue
                                }
                            } catch {
                                continue
                            }
                        }

                        guard let fileSize = resourceValues.fileSize,
                              let modDate = resourceValues.contentModificationDate else {
                            continue
                        }

                        filesScanned += 1
                        totalSizeScanned += UInt64(fileSize)

                        // Report progress periodically
                        if filesScanned % 1000 == 0 {
                            DispatchQueue.main.async {
                                self.scanProgress = .scanning(
                                    currentPath: url.path,
                                    filesScanned: filesScanned
                                )
                            }
                        }

                        // Check if it's a large file
                        if UInt64(fileSize) >= minimumSize {
                            let path = url.path

                            // Check exclusions
                            if self.isExcluded(path: path) {
                                continue
                            }

                            // Check if protected
                            let isProtected = self.configuration.isProtected(path) ||
                                self.isSystemProtected(path: path)

                            let result = LargeFileScanResult(
                                path: path,
                                name: url.lastPathComponent,
                                sizeBytes: UInt64(fileSize),
                                modificationDate: modDate,
                                isProtected: isProtected
                            )

                            largeFiles.append(result)

                            // Limit results
                            if largeFiles.count >= self.configuration.maxResults {
                                break
                            }
                        }
                    } catch {
                        // Skip files we can't access
                        continue
                    }
                }

                if largeFiles.count >= self.configuration.maxResults {
                    break
                }
            }

            guard !self.scanTask!.isCancelled else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.scanProgress = .idle
                }
                return
            }

            // Sort results by size descending
            largeFiles.sort { $0.sizeBytes > $1.sizeBytes }

            let scanDuration = Date().timeIntervalSince(startTime)
            let stats = ScanStatistics(
                totalFilesScanned: filesScanned,
                totalSizeScanned: totalSizeScanned,
                scanDuration: scanDuration,
                largeFilesFound: largeFiles.count
            )

            DispatchQueue.main.async {
                self.scanResults = largeFiles
                self.scanStatistics = stats
                self.scanProgress = .completed(results: largeFiles)
                self.isScanning = false
                print("[LargeFileFinder] Scan completed: \(largeFiles.count) large files found in \(String(format: "%.1f", scanDuration))s")
            }
        }

        scanTask = workItem
        scanQueue.async(execute: workItem)
    }

    /// Cancel ongoing scan
    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        isScanning = false
        scanProgress = .idle
    }

    /// Delete file with trash-first approach
    func deleteFile(_ file: LargeFileScanResult, moveToTrash: Bool = true) -> Result<Void, Error> {
        // Check if protected
        if file.isProtected || configuration.isProtected(file.path) {
            return .failure(LargeFileFinderError.protectedFile)
        }

        // Additional safety check
        if isSystemProtected(path: file.path) {
            return .failure(LargeFileFinderError.protectedFile)
        }

        do {
            if moveToTrash {
                // Move to trash
                try fileManager.trashItem(at: URL(fileURLWithPath: file.path), resultingItemURL: nil)
                print("[LargeFileFinder] Moved to trash: \(file.path)")
            } else {
                // Permanent delete (not recommended)
                try fileManager.removeItem(atPath: file.path)
                print("[LargeFileFinder] Permanently deleted: \(file.path)")
            }

            // Remove from results
            DispatchQueue.main.async {
                self.scanResults.removeAll { $0.id == file.id }
            }

            return .success(())
        } catch {
            print("[LargeFileFinder] Delete failed: \(error.localizedDescription)")
            return .failure(error)
        }
    }

    /// Sort results by option
    func sortResults(by option: LargeFileSortOption) {
        switch option {
        case .sizeDescending:
            scanResults.sort { $0.sizeBytes > $1.sizeBytes }
        case .sizeAscending:
            scanResults.sort { $0.sizeBytes < $1.sizeBytes }
        case .dateNewest:
            scanResults.sort { $0.modificationDate > $1.modificationDate }
        case .dateOldest:
            scanResults.sort { $0.modificationDate < $1.modificationDate }
        case .nameAZ:
            scanResults.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .category:
            scanResults.sort { $0.category.rawValue < $1.category.rawValue }
        }
    }

    // MARK: - Private Methods

    private func isExcluded(path: String) -> Bool {
        // Check excluded directories
        for excluded in configuration.excludedDirectories {
            if path.hasPrefix(excluded) {
                return true
            }
        }

        // Check excluded extensions
        let ext = (path as NSString).pathExtension.lowercased()
        if configuration.excludedExtensions.contains(ext) {
            return true
        }

        return false
    }

    private func isSystemProtected(path: String) -> Bool {
        let protectedPrefixes = [
            "/System",
            "/usr",
            "/bin",
            "/sbin",
            "/private/etc",
            "/private/var",
            NSHomeDirectory() + "/Library/Application Support/Pulse"
        ]

        for prefix in protectedPrefixes {
            if path.hasPrefix(prefix) {
                return true
            }
        }

        return false
    }
}

// MARK: - Errors

enum LargeFileFinderError: LocalizedError {
    case protectedFile
    case deleteFailed(String)
    case scanCancelled

    var errorDescription: String? {
        switch self {
        case .protectedFile:
            return "Cannot delete protected file"
        case .deleteFailed(let reason):
            return "Delete failed: \(reason)"
        case .scanCancelled:
            return "Scan was cancelled"
        }
    }
}