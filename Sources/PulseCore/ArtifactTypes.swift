//
//  ArtifactTypes.swift
//  PulseCore
//
//  Defines known artifact types that can be cleaned from project directories.
//

import Foundation

// MARK: - Artifact Type

/// A recognizable build artifact directory produced by developer tooling.
public struct ArtifactType: Sendable {
    /// Machine-identifiable name (e.g. "node_modules", ".build", "target").
    public let name: String
    /// Human-readable label for display.
    public let label: String
    /// The tool that produces this artifact (e.g. "npm", "SwiftPM", "Cargo").
    public let tool: String
    /// Estimated cleanup action.
    public let action: CleanupAction
    /// Warning shown when cleaning, if any.
    public let warning: String?

    public init(
        name: String,
        label: String,
        tool: String,
        action: CleanupAction = .file,
        warning: String? = nil
    ) {
        self.name = name
        self.label = label
        self.tool = tool
        self.action = action
        self.warning = warning
    }
}

// MARK: - Known Artifact Types

extension ArtifactType {
    /// All recognized artifact types. Add new types here as support grows.
    public static let allCases: [ArtifactType] = [
        nodeModules,
        swiftBuild,
        cargoTarget,
        dist,
        build,
        pythonVenv,
        pythonVenvAlt,
        pythonCache,
        dartTool,
        pods,
        nextCache,
        nuxtCache,
        parcelCache,
        elmStuff,
        goCache,
        bunCache,
    ]

    public static let nodeModules = ArtifactType(
        name: "node_modules",
        label: "Node modules",
        tool: "npm/yarn/pnpm",
        warning: "Removes installed packages — reinstall with npm/yarn/pnpm install"
    )

    public static let swiftBuild = ArtifactType(
        name: ".build",
        label: "Swift build artifacts",
        tool: "SwiftPM",
        warning: "Removes compiled outputs — rebuild with swift build"
    )

    public static let cargoTarget = ArtifactType(
        name: "target",
        label: "Cargo build artifacts",
        tool: "Cargo/Rust",
        warning: "Removes compiled outputs — rebuild with cargo build"
    )

    public static let dist = ArtifactType(
        name: "dist",
        label: "Distribution build",
        tool: "Bundler (Vite/Webpack/Rollup)",
        warning: "Removes production build — rebuild with your bundler"
    )

    public static let build = ArtifactType(
        name: "build",
        label: "Build output",
        tool: "Various",
        warning: "Removes build artifacts — may require rebuild"
    )

    public static let pythonVenv = ArtifactType(
        name: "venv",
        label: "Python virtual environment",
        tool: "Python venv",
        warning: "Removes virtual environment — recreate with python -m venv venv"
    )

    public static let pythonVenvAlt = ArtifactType(
        name: ".venv",
        label: "Python virtual environment",
        tool: "Python venv",
        warning: "Removes virtual environment — recreate with python -m venv .venv"
    )

    public static let pythonCache = ArtifactType(
        name: "__pycache__",
        label: "Python bytecode cache",
        tool: "Python",
        warning: "Removes compiled .pyc files — regenerated on next run"
    )

    public static let dartTool = ArtifactType(
        name: ".dart_tool",
        label: "Dart/Flutter tool cache",
        tool: "Dart/Flutter",
        warning: "Removes Dart tool cache — regenerated on next build"
    )

    public static let pods = ArtifactType(
        name: "Pods",
        label: "CocoaPods dependencies",
        tool: "CocoaPods",
        warning: "Removes pod dependencies — reinstall with pod install"
    )

    public static let nextCache = ArtifactType(
        name: ".next",
        label: "Next.js build cache",
        tool: "Next.js",
        warning: "Removes build cache — regenerated on next dev/build"
    )

    public static let nuxtCache = ArtifactType(
        name: ".nuxt",
        label: "Nuxt.js build cache",
        tool: "Nuxt.js",
        warning: "Removes build cache — regenerated on next dev/build"
    )

    public static let parcelCache = ArtifactType(
        name: ".parcel-cache",
        label: "Parcel build cache",
        tool: "Parcel",
        warning: "Removes build cache — regenerated on next build"
    )

    public static let elmStuff = ArtifactType(
        name: "elm-stuff",
        label: "Elm build artifacts",
        tool: "Elm",
        warning: "Removes compiled Elm — rebuilt on next elm make"
    )

    public static let goCache = ArtifactType(
        name: "go-cache",
        label: "Go module cache",
        tool: "Go",
        warning: "Removes downloaded modules — re-downloaded on next go build"
    )

    public static let bunCache = ArtifactType(
        name: "bun-cache",
        label: "Bun package cache",
        tool: "Bun",
        warning: "Removes cached packages — re-downloaded on next bun install"
    )
}

// MARK: - Artifact Scan Config

/// Configuration for the artifact scanner.
public struct ArtifactScanConfig: Sendable {
    /// Directories to scan for project folders.
    public let scanPaths: [String]
    /// Minimum age (days) for a project's artifact to be considered for cleanup.
    /// Projects modified more recently than this are skipped by default.
    public let minAgeDays: Int
    /// Minimum artifact size (MB) to report.
    public let minSizeMB: Double
    /// Artifact types to look for.
    public let artifactTypes: [ArtifactType]
    /// Paths to exclude from scanning (protected directories).
    public let excludedPaths: Set<String>

    public init(
        scanPaths: [String] = ArtifactScanConfig.defaultScanPaths,
        minAgeDays: Int = 7,
        minSizeMB: Double = 100,
        artifactTypes: [ArtifactType] = ArtifactType.allCases,
        excludedPaths: Set<String> = []
    ) {
        self.scanPaths = scanPaths
        self.minAgeDays = minAgeDays
        self.minSizeMB = minSizeMB
        self.artifactTypes = artifactTypes
        self.excludedPaths = excludedPaths
    }

    /// Default directories to scan for project folders.
    public static let defaultScanPaths: [String] = [
        NSString(string: "~/Projects").expandingTildeInPath,
        NSString(string: "~/Developer").expandingTildeInPath,
        NSString(string: "~/GitHub").expandingTildeInPath,
        NSString(string: "~/Code").expandingTildeInPath,
        NSString(string: "~/Work").expandingTildeInPath,
        NSString(string: "~/Documents").expandingTildeInPath,
    ]
}

// MARK: - Artifact Item

/// A single build artifact found inside a project directory.
public struct ArtifactItem: Sendable {
    /// The project directory that contains this artifact.
    public let projectPath: String
    /// The artifact directory name (e.g. "node_modules").
    public let artifactName: String
    /// Full path to the artifact directory.
    public let artifactPath: String
    /// Estimated size in megabytes.
    public let sizeMB: Double
    /// When the artifact directory was last modified.
    public let lastModified: Date
    /// How old the artifact is in days.
    public let ageDays: Int
    /// Whether this artifact was recently modified (within minAgeDays).
    public let isRecent: Bool
    /// The artifact type definition.
    public let type: ArtifactType
    /// The cleanup action to take.
    public let action: CleanupAction

    var priority: CleanupPriority {
        guard !isRecent else { return .optional }
        if sizeMB >= 1024 { return .high }
        if sizeMB >= 500 { return .medium }
        return .low
    }

    var category: CleanupCategory {
        .developer
    }

    /// Human-readable summary line for display.
    var summaryLine: String {
        let project = (projectPath as NSString).lastPathComponent
        let age = isRecent ? "Recent" : ageText
        return "\(project)/\(artifactName) — \(sizeText) — \(age)"
    }

    public var sizeText: String {
        if sizeMB >= 1024 {
            return String(format: "%.1f GB", sizeMB / 1024)
        }
        return String(format: "%.0f MB", sizeMB)
    }

    public var ageText: String {
        if ageDays >= 365 {
            return "\(ageDays / 365) year(s) ago"
        }
        if ageDays >= 30 {
            return "\(ageDays / 30) month(s) ago"
        }
        return "\(ageDays) day(s) ago"
    }
}
