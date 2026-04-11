import Foundation
import UniformTypeIdentifiers

// MARK: - File Category

enum FileCategory: String, Codable, CaseIterable, Identifiable {
    case applications = "Applications"
    case documents = "Documents"
    case downloads = "Downloads"
    case media = "Media"
    case archives = "Archives"
    case cache = "Cache"
    case logs = "Logs"
    case other = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .applications: return "app.badge"
        case .documents: return "doc.text"
        case .downloads: return "arrow.down.circle"
        case .media: return "photo.movie"
        case .archives: return "archivebox"
        case .cache: return "trash"
        case .logs: return "doc.plaintext"
        case .other: return "doc"
        }
    }

    var color: String {
        switch self {
        case .applications: return "blue"
        case .documents: return "green"
        case .downloads: return "purple"
        case .media: return "pink"
        case .archives: return "orange"
        case .cache: return "gray"
        case .logs: return "yellow"
        case .other: return "secondary"
        }
    }

    /// Detect category from file extension
    static func from(extension ext: String) -> FileCategory {
        let lowercased = ext.lowercased()

        // Applications
        if lowercased == "app" {
            return .applications
        }

        // Media
        let mediaExtensions = [
            "jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tiff",
            "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm",
            "mp3", "wav", "aac", "flac", "m4a", "ogg",
            "psd", "ai", "sketch", "fig"
        ]
        if mediaExtensions.contains(lowercased) {
            return .media
        }

        // Archives
        let archiveExtensions = ["zip", "tar", "gz", "7z", "rar", "dmg", "iso", "pkg"]
        if archiveExtensions.contains(lowercased) {
            return .archives
        }

        // Documents
        let documentExtensions = [
            "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx",
            "txt", "rtf", "md", "markdown",
            "pages", "numbers", "keynote"
        ]
        if documentExtensions.contains(lowercased) {
            return .documents
        }

        // Downloads (common download extensions)
        let downloadExtensions = ["exe", "msi", "deb", "rpm", "apk", "ipa"]
        if downloadExtensions.contains(lowercased) {
            return .downloads
        }

        // Cache
        let cacheExtensions = ["cache", "tmp", "temp", "bak", "old"]
        if cacheExtensions.contains(lowercased) {
            return .cache
        }

        // Logs
        let logExtensions = ["log", "err", "out"]
        if logExtensions.contains(lowercased) {
            return .logs
        }

        return .other
    }
}

// MARK: - Large File Scan Result

struct LargeFileScanResult: Identifiable, Codable {
    let id: UUID
    let path: String
    let name: String
    let sizeBytes: UInt64
    let category: FileCategory
    let fileExtension: String
    let modificationDate: Date
    let isProtected: Bool

    init(
        path: String,
        name: String,
        sizeBytes: UInt64,
        modificationDate: Date,
        isProtected: Bool = false
    ) {
        self.id = UUID()
        self.path = path
        self.name = name
        self.sizeBytes = sizeBytes
        self.fileExtension = (path as NSString).pathExtension.lowercased()
        self.category = FileCategory.from(extension: fileExtension)
        self.modificationDate = modificationDate
        self.isProtected = isProtected
    }

    // Computed properties

    var sizeMB: Double { Double(sizeBytes) / (1024 * 1024) }
    var sizeGB: Double { Double(sizeBytes) / (1024 * 1024 * 1024) }

    var formattedSize: String {
        if sizeGB >= 1.0 {
            return String(format: "%.2f GB", sizeGB)
        } else if sizeMB >= 1.0 {
            return String(format: "%.1f MB", sizeMB)
        } else {
            return String(format: "%.0f KB", Double(sizeBytes) / 1024)
        }
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: modificationDate)
    }

    var parentDirectory: String {
        (path as NSString).deletingLastPathComponent
    }
}

// MARK: - Scan Configuration

struct ScanConfiguration {
    /// Minimum file size to be considered "large" (default: 100 MB)
    var minimumSizeMB: Double = 100

    /// Directories to scan
    var directoriesToScan: [String] = []

    /// Directories to exclude from scan
    var excludedDirectories: Set<String> = [
        "/System",
        "/Library/SystemMigration",
        "/private/var/vm" // Swap files
    ]

    /// File extensions to exclude
    var excludedExtensions: Set<String> = [
        "sparsebundle", "sparseimage" // Disk images can be huge but are often in use
    ]

    /// Whether to follow symlinks
    var followSymlinks: Bool = false

    /// Maximum number of files to return
    var maxResults: Int = 100

    /// Protected paths (whitelist) - files in these paths cannot be deleted
    var protectedPaths: Set<String> = []

    init() {
        // Default scan directories
        directoriesToScan = [
            NSHomeDirectory(),
            "/Volumes"
        ].filter { FileManager.default.fileExists(atPath: $0) }
    }

    mutating func addProtectedPath(_ path: String) {
        protectedPaths.insert(path)
    }

    func isProtected(_ path: String) -> Bool {
        for protected in protectedPaths {
            if path.hasPrefix(protected) {
                return true
            }
        }
        return false
    }
}

// MARK: - Scan Progress

enum ScanProgress {
    case idle
    case scanning(currentPath: String, filesScanned: Int)
    case sorting
    case completed(results: [LargeFileScanResult])
    case failed(error: String)

    var isScanning: Bool {
        if case .scanning = self {
            return true
        }
        return false
    }

    var progressText: String {
        switch self {
        case .idle:
            return "Ready to scan"
        case .scanning(let path, let count):
            return "Scanning: \(count) files... \n\(path)"
        case .sorting:
            return "Sorting results..."
        case .completed(let results):
            return "Found \(results.count) large files"
        case .failed(let error):
            return "Scan failed: \(error)"
        }
    }
}

// MARK: - Sort Option

enum LargeFileSortOption: String, CaseIterable {
    case sizeDescending = "Largest First"
    case sizeAscending = "Smallest First"
    case dateNewest = "Newest First"
    case dateOldest = "Oldest First"
    case nameAZ = "Name (A-Z)"
    case category = "Category"
}

// MARK: - Scan Statistics

struct ScanStatistics {
    let totalFilesScanned: Int
    let totalSizeScanned: UInt64
    let scanDuration: TimeInterval
    let largeFilesFound: Int

    var formattedTotalSize: String {
        let gb = Double(totalSizeScanned) / (1024 * 1024 * 1024)
        return String(format: "%.2f GB", gb)
    }

    var formattedDuration: String {
        return String(format: "%.1f seconds", scanDuration)
    }
}