//
//  DirectoryScanner.swift
//  PulseCore
//
//  Estimates directory sizes using du -sk or FileManager enumeration.
//  Pure Swift, no AppKit.
//

import Foundation

/// Scans directories and estimates their sizes.
public struct DirectoryScanner {
    public init() {}

    /// Estimate the size of a directory in MB.
    /// Tilde-expands paths. Returns 0 if directory does not exist.
    public func directorySizeMB(_ path: String) -> Double {
        let expandedPath = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expandedPath) else {
            return 0
        }

        // Use du -sk for fast estimation
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
        } catch {
            // Fall back to FileManager enumeration
            return directorySizeFallbackMB(expandedPath)
        }

        return 0
    }

    /// Fallback: enumerate directory contents manually.
    private func directorySizeFallbackMB(_ path: String) -> Double {
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(at: URL(fileURLWithPath: path), includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }

        var totalBytes: UInt64 = 0
        for case let url as URL in enumerator {
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                totalBytes += UInt64(size)
            }
        }

        return Double(totalBytes) / (1024.0 * 1024.0)
    }
}
