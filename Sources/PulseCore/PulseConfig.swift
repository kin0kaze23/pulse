//
//  PulseConfig.swift
//  PulseCore
//
//  User configuration for Pulse CLI.
//  Reads from ~/.config/pulse/config.json with sensible defaults.
//  Pure Swift, no AppKit, no SwiftUI, no ObservableObject, no @Published.
//

import Foundation

// MARK: - Configuration

/// User configuration for Pulse CLI operations.
/// Loaded from `~/.config/pulse/config.json`. All fields have safe defaults.
public struct PulseConfig: Codable, Sendable {
    /// Directories to scan for project artifacts.
    public var artifactScanPaths: [String]?
    /// Minimum age (days) before an artifact is considered for cleanup.
    public var artifactMinAgeDays: Int?
    /// Minimum artifact size (MB) to report.
    public var artifactMinSizeMB: Double?
    /// Paths to always exclude from cleanup (protected directories).
    public var excludedPaths: [String]?
    /// Default action when running `pulse clean` without a profile.
    public var defaultCleanProfile: String?

    public init(
        artifactScanPaths: [String]? = nil,
        artifactMinAgeDays: Int? = nil,
        artifactMinSizeMB: Double? = nil,
        excludedPaths: [String]? = nil,
        defaultCleanProfile: String? = nil
    ) {
        self.artifactScanPaths = artifactScanPaths
        self.artifactMinAgeDays = artifactMinAgeDays
        self.artifactMinSizeMB = artifactMinSizeMB
        self.excludedPaths = excludedPaths
        self.defaultCleanProfile = defaultCleanProfile
    }
}

// MARK: - Config Loading

extension PulseConfig {
    /// Default config path: ~/.config/pulse/config.json
    public static let defaultConfigURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".config/pulse/config.json")
    }()

    /// Load config from the default path, or return defaults if not found.
    public static func load() -> PulseConfig {
        load(from: defaultConfigURL)
    }

    /// Load config from a specific path, or return defaults if not found.
    public static func load(from url: URL) -> PulseConfig {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let config = try? JSONDecoder().decode(PulseConfig.self, from: data) else {
            return PulseConfig()
        }
        return config
    }

    /// Save config to the default path, creating parent directories as needed.
    public func save() throws {
        try save(to: Self.defaultConfigURL)
    }

    /// Save config to a specific path.
    public func save(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        let dir = url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}

// MARK: - Defaults

extension PulseConfig {
    /// Default scan paths for artifact scanning.
    public var effectiveArtifactScanPaths: [String] {
        artifactScanPaths ?? ArtifactScanConfig.defaultScanPaths
    }

    /// Default minimum age in days.
    public var effectiveArtifactMinAgeDays: Int {
        artifactMinAgeDays ?? 7
    }

    /// Default minimum size in MB.
    public var effectiveArtifactMinSizeMB: Double {
        artifactMinSizeMB ?? 100
    }

    /// Default excluded paths.
    public var effectiveExcludedPaths: Set<String> {
        Set(excludedPaths ?? [])
    }
}
