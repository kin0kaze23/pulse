//
//  DiskExplorerService.swift
//  Pulse
//
//  Disk Explorer service for analyzing disk usage with tree structures
//  Similar in concept to Grand Perspective but fully native
//

import Foundation
import AppKit
import Combine

// MARK: - Type Definitions
enum FolderType {
    case regular
    case documents
    case downloads
    case desktop
    case libraryCache
    case packages
    case temporary
}

enum FileType {
    case document
    case image
    case video
    case archive
    case code
    case other
}

// MARK: - Disk Folder Structure Model

struct DiskFolder: Identifiable, Equatable {
    let id = UUID()
    let path: String
    let name: String
    let sizeBytes: Int64
    let subfolders: [DiskFolder]
    let files: [DiskFile]
    let type: FolderType
    let modifiedDate: Date?
    let isRoot: Bool
    
    var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
    
    struct DiskFile: Identifiable, Equatable {
        let id = UUID()
        let path: String
        let name: String
        let sizeBytes: Int64
        let fileType: FileType
        let modifiedDate: Date?
        
        var sizeFormatted: String {
            ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
        }
        
        static func == (lhs: DiskFile, rhs: DiskFile) -> Bool {
            return lhs.id == rhs.id && lhs.path == rhs.path
        }
    }
    
    static func == (lhs: DiskFolder, rhs: DiskFolder) -> Bool {
        return lhs.id == rhs.id && lhs.path == rhs.path
    }
}

// MARK: - Disk Explorer Service

class DiskExplorerService: ObservableObject {
    static let shared = DiskExplorerService()
    
    @Published var selectedRootPath: String = "/" {
        didSet {
            startAnalysis()
        }
    }
    
    @Published var rootFolder: DiskFolder?
    @Published var isAnalyzing = false
    @Published var analysisProgress: Double = 0.0
    @Published var statusMessage = "Ready to analyze"
    @Published var largeFiles: [DiskFolder.DiskFile] = []  // Large files directly in root
    
    private var analysisTask: Task<Void, Error>?
    private let fileManager = FileManager.default
    
    private init() {
        startAnalysis()
    }
    
    func startAnalysis() {
        // Cancel previous analysis
        analysisTask?.cancel()
        
        // Start new analysis task
        analysisTask = Task {
            try await analyzeDisk(rootPath: selectedRootPath)
        }
    }
    
    private func analyzeDisk(rootPath: String) async throws {
        guard !Task.isCancelled else { return }
        
        await MainActor.run {
            isAnalyzing = true
            statusMessage = "Scanning folders..."
            analysisProgress = 0.0
        }
        
        do {
            let folder = try await analyzeFolder(at: rootPath, isRoot: true)
            
            await MainActor.run {
                rootFolder = folder
                largeFiles = findLargeFiles(at: rootPath).prefix(20).map { $0.0 }
                isAnalyzing = false
                statusMessage = "Analysis complete"
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                statusMessage = "Error: \(error.localizedDescription)"
            }
        }
    }
    
    private func analyzeFolder(at path: String, isRoot: Bool = false) async throws -> DiskFolder {
        // Check for cancellation periodically
        guard !Task.isCancelled else { throw CancellationError() }
        
        let url = URL(fileURLWithPath: path)
        let attributes = try fileManager.attributesOfItem(atPath: path)
        let modificationDate = attributes[.modificationDate] as? Date
        
        // Get immediate subfiles and subfolders
        let contents = try fileManager.contentsOfDirectory(atPath: path)
        
        var subfolders: [DiskFolder] = []
        var files: [DiskFolder.DiskFile] = []
        var totalSize: Int64 = 0
        
        // First pass: gather immediate children
        for item in contents {
            guard !Task.isCancelled else { throw CancellationError() }
            
            let itemPath = "\(path)/\(item)"
            let itemURL = URL(fileURLWithPath: itemPath)
            
            let isDirectory = itemURL.hasDirectoryPath
            
            if isDirectory {
                // Skip hidden directories like .Trashes, .Spotlight-V100, etc.
                if item.hasPrefix(".") { continue }
                
                // For this first pass, just get total size without recursion
                // We'll fully analyze each folder separately later if requested
                let folderSize = calculateFolderSize(at: itemPath)
                let folderType = determineFolderType(path: itemPath, name: item)
                
                let folder = DiskFolder(
                    path: itemPath,
                    name: item,
                    sizeBytes: folderSize,
                    subfolders: [],  // Will be analyzed when user drills down
                    files: [],       // Will be analyzed when user drills down
                    type: folderType,
                    modifiedDate: calculateFolderModifiedDate(at: itemPath),
                    isRoot: false
                )
                
                subfolders.append(folder)
                totalSize += folderSize
            } else {
                let attributes = try? fileManager.attributesOfItem(atPath: itemPath)
                let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
                let modDate = (attributes?[.modificationDate] as? Date)
                
                if let fileType = determineFileType(itemPath) {
                    let file = DiskFolder.DiskFile(
                        path: itemPath,
                        name: item,
                        sizeBytes: size,
                        fileType: fileType,
                        modifiedDate: modDate
                    )
                    
                    files.append(file)
                }
                totalSize += size
            }
        }
        
        // Sort results (largest first)
        subfolders.sort { $0.sizeBytes > $1.sizeBytes }
        files.sort { $0.sizeBytes > $1.sizeBytes }
        
        let folderType = determineRootFolderType(path: path)
        
        return DiskFolder(
            path: path,
            name: url.lastPathComponent.isEmpty ? "Root" : url.lastPathComponent,
            sizeBytes: totalSize,
            subfolders: subfolders,
            files: files,
            type: isRoot ? folderType : .regular,
            modifiedDate: modificationDate,
            isRoot: isRoot
        )
    }
    
    private func calculateFolderSize(at path: String) -> Int64 {
        // Use `du -sk` for fast directory size estimation - much faster than enumeration
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        task.arguments = ["-sk", path]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            // du -sk output format: "12345\t/path/to/dir"
            let kb = output.split(separator: "\t").first.flatMap { Double($0) } ?? 0
            return Int64(kb * 1024) // KB to bytes
        } catch {
            // Fallback to quick enumeration with strict limit
            return quickFolderSizeEnumeration(at: path, maxItems: 5000)
        }
    }
    
    private func quickFolderSizeEnumeration(at path: String, maxItems: Int) -> Int64 {
        let url = URL(fileURLWithPath: path)
        guard url.hasDirectoryPath else { return 0 }
        
        var size: Int64 = 0
        var itemCount = 0
        
        if let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let fileURL as URL in enumerator {
                itemCount += 1
                if itemCount > maxItems {
                    // Estimate remaining based on average so far
                    let avgSize = itemCount > 0 ? Double(size) / Double(itemCount) : 0
                    size += Int64(avgSize * 1000) // Rough estimate
                    break
                }
                
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
            }
        }
        return size
    }
    
    private func calculateFolderModifiedDate(at path: String) -> Date? {
        // Use the folder's own modification date instead of enumerating all files
        // This is much faster and sufficient for display purposes
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let modDate = attrs[.modificationDate] as? Date {
            return modDate
        }
        return nil
    }
    
    func drillDown(to folder: DiskFolder) async throws -> DiskFolder {
        // Analyze this folder completely with all subfolder details
        return try await analyzeFolder(at: folder.path)
    }
    
    private func determineFolderType(path: String, name: String? = nil) -> FolderType {
        let lowerName = (name ?? URL(fileURLWithPath: path).lastPathComponent).lowercased()
        
        if lowerName.contains("package") || lowerName.contains("pkg") {
            return .packages
        } else if lowerName.contains("cache") || lowerName.contains(".cache") {
            return .libraryCache
        } else if lowerName.contains("tmp") || lowerName.contains("temp") {
            return .temporary
        }
        
        return .regular
    }
    
    private func determineRootFolderType(path: String) -> FolderType {
        let lowerPath = path.lowercased()
        
        if lowerPath.contains("documents") {
            return .documents
        } else if lowerPath.contains("downloads") {
            return .downloads
        } else if lowerPath.contains("desktop") {
            return .desktop
        } else if lowerPath.contains("library") && lowerPath.contains("caches") {
            return .libraryCache
        } else if lowerPath.hasSuffix("/") {
            return .regular  // Usually root drive
        } else {
            return determineFolderType(path: path, name: nil)
        }
    }
    
    private func determineFileType(_ path: String) -> FileType? {
        let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
        
        if ext.isEmpty { return nil }
        
        switch ext {
        case "txt", "rtf", "doc", "docx", "pdf", "pages", "numbers":
            return .document
        case "jpg", "jpeg", "png", "gif", "heic", "tiff", "bmp":
            return .image
        case "mp4", "mov", "avi", "mkv", "wmv":
            return .video
        case "zip", "tar", "gz", "rar", "7z", "pkg", "dmg":
            return .archive
        case "swift", "js", "ts", "py", "rb", "java", "cpp", "h", "c", "go", "rs", "html", "css":
            return .code
        default:
            return .other
        }
    }
    
    private func findLargeFiles(at path: String) -> [(DiskFolder.DiskFile, Int64)] {
        let url = URL(fileURLWithPath: path)
        var results: [(DiskFolder.DiskFile, Int64)] = []
        
        if let enumerator = FileManager.default.enumerator(at: url,
                                                           includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                                                           options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]) {
            for case let fileURL as URL in enumerator {
                if let fileType = determineFileType(fileURL.path) {
                    let attr = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let size = attr?.fileSize ?? 0
                    let modDate = attr?.contentModificationDate
                
                    // Only include really large files (> 100MB)
                    if size > 100_000_000 {
                        let file = DiskFolder.DiskFile(
                            path: fileURL.path,
                            name: fileURL.lastPathComponent,
                            sizeBytes: Int64(size),
                            fileType: fileType,
                            modifiedDate: modDate
                        )
                        results.append((file, Int64(size)))
                    }
                }
            }
        }
        
        return results.sorted { $0.1 > $1.1 }  // Sort by size (descending)
    }
}