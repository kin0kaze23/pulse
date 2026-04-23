//
//  DirectorySizeUtility.swift
//  Pulse
//
//  Consolidated directory size calculation utilities
//  Replaces duplicate methods across ComprehensiveOptimizer, StorageAnalyzer, MemoryOptimizer, etc.
//

import Foundation

/// Utility for calculating directory sizes
/// Uses `du -sk` for accuracy and performance on large directories
enum DirectorySizeUtility {
    
    // MARK: - Primary Methods
    
    /// Calculate directory size in bytes using `du -sk`
    /// - Parameter path: Directory path (supports ~ expansion)
    /// - Returns: Size in bytes, or 0 if path doesn't exist or fails
    static func directorySizeBytes(_ path: String) -> UInt64 {
        let expanded = (path as NSString).expandingTildeInPath
        
        guard FileManager.default.fileExists(atPath: expanded) else { return 0 }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/du")
        task.arguments = ["-sk", expanded]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return 0 }
            
            // du -sk output format: "12345\t/path/to/dir"
            let kb = output.split(separator: "\t").first.flatMap { Double($0) } ?? 0
            return UInt64(kb * 1024) // KB to bytes
        } catch {
            return 0
        }
    }
    
    /// Calculate directory size in megabytes
    /// - Parameter path: Directory path (supports ~ expansion)
    /// - Returns: Size in MB, or 0 if path doesn't exist or fails
    static func directorySizeMB(_ path: String) -> Double {
        Double(directorySizeBytes(path)) / (1024 * 1024)
    }
    
    /// Calculate directory size in gigabytes
    /// - Parameter path: Directory path (supports ~ expansion)
    /// - Returns: Size in GB, or 0 if path doesn't exist or fails
    static func directorySizeGB(_ path: String) -> Double {
        Double(directorySizeBytes(path)) / (1024 * 1024 * 1024)
    }
    
    // MARK: - Quick Estimate (for performance-critical cases)
    
    /// Quick directory size estimation - uses `du -sk` for speed
    /// - Parameters:
    ///   - path: Directory path (supports ~ expansion)
    ///   - maxItems: Legacy parameter - no longer used, kept for API compatibility
    /// - Returns: Size in MB using fast `du -sk` command
    static func quickDirectorySizeMB(_ path: String, maxItems: Int = 1000) -> Double {
        // Always use du -sk for speed - it's much faster than enumeration
        return directorySizeMB(path)
    }
    
    // MARK: - File Enumeration (for smaller directories)
    
    /// Calculate directory size using file enumeration (slower but more control)
    /// Use this for smaller directories where you need precise results
    /// - Parameter path: Directory path (supports ~ expansion)
    /// - Returns: Size in MB
    static func directorySizeByEnumerationMB(_ path: String) -> Double {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return 0 }
        
        var total: UInt64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: expanded),
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += UInt64(size)
                }
            }
        }
        return Double(total) / (1024 * 1024)
    }
}

// MARK: - String Extension for Tilde Expansion

extension String {
    /// Expands ~ to home directory path
    var expandingTilde: String {
        (self as NSString).expandingTildeInPath
    }
}