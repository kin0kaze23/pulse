//
//  SafetyValidator.swift
//  PulseCore
//
//  Validates whether a path is safe to delete.
//  Pure Swift, no AppKit, no Foundation beyond FileManager.
//  This is the single source of truth for path safety.
//

import Foundation

/// Validates cleanup paths against protected system paths and user-defined exclusions.
public struct SafetyValidator {
    /// User-defined paths to exclude from cleanup.
    private let excludedPaths: [String]

    public init(excludedPaths: [String] = []) {
        self.excludedPaths = excludedPaths
    }

    /// Check if a path is safe to delete (not a critical system path).
    /// Returns false for protected paths, true for allowed paths.
    public func isPathSafeToDelete(_ path: String) -> Bool {
        let lowerPath = path.lowercased()

        // Critical system paths that should NEVER be deleted
        let protectedPaths = [
            "/system", "/bin", "/sbin", "/usr", "/var", "/etc",
            "/applications", "/library", "/network", "/cores",
            "/dev", "/tmp", "/private"
        ]

        for protected in protectedPaths {
            if lowerPath.hasPrefix(protected + "/") || lowerPath == protected {
                // Exception: user-writable subdirectories
                if protected == "/var" && lowerPath.contains("/var/folders") {
                    continue  // Allow /var/folders cleanup
                }
                if protected == "/tmp" && lowerPath.hasPrefix("/var/tmp") {
                    continue  // Allow /var/tmp cleanup
                }
                return false
            }
        }

        // Protect user home directory root
        let homeDir = FileManager.default.homeDirectoryForCurrentUser.path
        if path == homeDir ||
           path.hasPrefix(homeDir + "/Documents") ||
           path.hasPrefix(homeDir + "/Desktop") ||
           path.hasPrefix(homeDir + "/Downloads") {
            // Exception: individual files inside Downloads can be cleaned
            if path.hasPrefix(homeDir + "/Downloads") && path != homeDir + "/Downloads" {
                return true
            }
            return false
        }

        // Protect app bundles
        if lowerPath.hasSuffix(".app") || lowerPath.hasSuffix(".app/") {
            return false
        }

        // User-defined exclusions
        for excluded in excludedPaths {
            if path.contains(excluded) {
                return false
            }
        }

        return true
    }
}
