//
//  ArtifactsCommand.swift
//  PulseCLI
//
//  "pulse artifacts" — scan and clean build artifacts from project directories.
//

import Foundation
import PulseCore

enum ArtifactsCommand {

    // MARK: - Run

    static func run(_ args: [String]) -> Int32 {
        let parsed = parseArgs(args)

        switch parsed {
        case .help:
            print("Usage:")
            print("  pulse artifacts                  Scan for build artifacts")
            print("  pulse artifacts --apply          Clean found artifacts")
            print()
            print("Options:")
            print("  --dry-run         Show what would be cleaned (default)")
            print("  --apply           Execute cleanup")
            print("  --yes, -y         Skip confirmation prompt (CI/CD)")
            print("  --json            Output as JSON")
            print("  --all             Include recently modified projects")
            return EXIT_SUCCESS

        case .missingAction(let force, let json, let includeRecent):
            // Default behavior: scan and display (no destructive action)
            return runScan(apply: false, force: force, json: json, includeRecent: includeRecent)

        case .scan(let apply, let force, let json, let includeRecent):
            return runScan(apply: apply, force: force, json: json, includeRecent: includeRecent)
        }
    }

    // MARK: - Argument Parsing

    private enum ParsedArgs {
        case help
        case missingAction(force: Bool, json: Bool, includeRecent: Bool)
        case scan(apply: Bool, force: Bool, json: Bool, includeRecent: Bool)
    }

    private static func parseArgs(_ args: [String]) -> ParsedArgs {
        var action: ParsedArgs?
        var force = false
        var json = false
        var includeRecent = false

        json = args.contains("--json")
        force = args.contains("--yes") || args.contains("-y")
        includeRecent = args.contains("--all")

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--help", "-h":
                return .help
            case "--json", "--yes", "-y", "--all":
                break
            case "--apply":
                action = .scan(apply: true, force: force, json: json, includeRecent: includeRecent)
            case "--dry-run":
                action = .scan(apply: false, force: force, json: json, includeRecent: includeRecent)
            default:
                break
            }
            i += 1
        }

        return action ?? .missingAction(force: force, json: json, includeRecent: includeRecent)
    }

    // MARK: - Scan

    private static func runScan(apply: Bool, force: Bool, json: Bool, includeRecent: Bool) -> Int32 {
        let scanner = ArtifactScanner()
        let userConfig = PulseConfig.load()

        var config = ArtifactScanConfig(
            scanPaths: userConfig.effectiveArtifactScanPaths,
            minAgeDays: includeRecent ? 0 : userConfig.effectiveArtifactMinAgeDays,
            minSizeMB: userConfig.effectiveArtifactMinSizeMB,
            excludedPaths: userConfig.effectiveExcludedPaths
        )

        if includeRecent {
            config = ArtifactScanConfig(
                scanPaths: userConfig.effectiveArtifactScanPaths,
                minAgeDays: 0,
                minSizeMB: userConfig.effectiveArtifactMinSizeMB,
                excludedPaths: userConfig.effectiveExcludedPaths
            )
        }

        let artifacts = scanner.scan(config: config)

        if artifacts.isEmpty && !includeRecent {
            if json {
                return outputJSON([])
            }
            print("  No build artifacts found in default scan paths.")
            print()
            print("  Pulse looks for node_modules, .build, target, dist,")
            print("  venv, __pycache__, .dart_tool, and Pods in:")
            for path in ArtifactScanConfig.defaultScanPaths {
                print("    \(path)")
            }
            print()
            print("  Use 'pulse artifacts --all' to include recently modified projects.")
            return EXIT_SUCCESS
        }

        if artifacts.isEmpty {
            if json {
                return outputJSON([])
            }
            print("  No build artifacts found.")
            return EXIT_SUCCESS
        }

        // Filter out recent items unless --all
        let displayItems = includeRecent ? artifacts : artifacts.filter { !$0.isRecent }

        if displayItems.isEmpty && !includeRecent {
            if json {
                return outputJSON(artifacts)
            }
            print("  All artifacts are from recently modified projects.")
            print("  Use 'pulse artifacts --all' to include them.")
            return EXIT_SUCCESS
        }

        let itemsToClean = apply ? displayItems : artifacts
        let plan = scanner.plan(from: itemsToClean)

        if json {
            return outputJSON(apply ? displayItems : artifacts)
        }

        if apply {
            return runApply(artifacts: displayItems, plan: plan, force: force)
        }

        return outputHuman(artifacts: artifacts, displayItems: displayItems)
    }

    // MARK: - Human Output

    private static func outputHuman(artifacts: [ArtifactItem], displayItems: [ArtifactItem]) -> Int32 {
        let displayTotal = displayItems.reduce(0) { $0 + $1.sizeMB }
        let allTotal = artifacts.reduce(0) { $0 + $1.sizeMB }

        print(OutputFormatter.bold("Pulse"))
        print()
        print(OutputFormatter.bold("Project Artifacts"))

        if artifacts.count != displayItems.count {
            let skipped = artifacts.count - displayItems.count
            print(OutputFormatter.dim("\(displayItems.count) item(s) reclaimable · \(skipped) skipped (recently modified)"))
        } else {
            print(OutputFormatter.dim("\(displayItems.count) item(s) reclaimable"))
        }

        print()

        // Table
        let headers = ["Project", "Artifact", "Size", "Tool", "Last Modified"]
        let rows = displayItems.map { item -> [String] in
            let project = (item.projectPath as NSString).lastPathComponent
            let age = item.isRecent ? OutputFormatter.yellow("Recent") : item.ageText
            return [
                project,
                item.artifactName,
                OutputFormatter.formatSizeMB(item.sizeMB),
                item.type.tool,
                age,
            ]
        }

        print(OutputFormatter.table(headers: headers, rows: rows))

        // Summary
        print()
        print("  \(OutputFormatter.bold("Total reclaimable:")) \(OutputFormatter.formatSizeMB(displayTotal))")

        if artifacts.count != displayItems.count {
            print("  \(OutputFormatter.dim("Total including recent:")) \(OutputFormatter.dim(OutputFormatter.formatSizeMB(allTotal)))")
        }

        // Warnings
        let itemsWithWarnings = displayItems.filter { $0.type.warning != nil }
        if !itemsWithWarnings.isEmpty {
            print()
            for item in itemsWithWarnings {
                print(OutputFormatter.formatWarning(item.type.warning!))
            }
        }

        // Footer
        print()
        print(OutputFormatter.dim("Run 'pulse artifacts --apply' to clean these artifacts."))
        print(OutputFormatter.dim("Run 'pulse artifacts --apply --yes' for CI/CD automation."))
        print(OutputFormatter.dim("Run 'pulse artifacts --all' to include recently modified projects."))

        return EXIT_SUCCESS
    }

    // MARK: - Apply

    private static func runApply(artifacts: [ArtifactItem], plan: CleanupPlan, force: Bool) -> Int32 {
        let displayItems = artifacts
        let totalMB = displayItems.reduce(0) { $0 + $1.sizeMB }

        print(OutputFormatter.bold("Pulse"))
        print()
        print(OutputFormatter.bold("Cleanup Preview — Artifacts"))
        print()

        // Table
        let headers = ["Project", "Artifact", "Size", "Action"]
        let rows = displayItems.map { item -> [String] in
            let project = (item.projectPath as NSString).lastPathComponent
            return [
                project,
                item.artifactName,
                OutputFormatter.formatSizeMB(item.sizeMB),
                "delete",
            ]
        }

        print(OutputFormatter.table(headers: headers, rows: rows))
        print()
        print("  \(OutputFormatter.bold("Total reclaimable:")) \(OutputFormatter.formatSizeMB(totalMB))")

        // Warnings
        let itemsWithWarnings = displayItems.filter { $0.type.warning != nil }
        if !itemsWithWarnings.isEmpty {
            print()
            for item in itemsWithWarnings {
                print(OutputFormatter.formatWarning(item.type.warning!))
            }
        }

        // Confirmation
        if !force {
            print()
            print(OutputFormatter.yellow("This action will permanently delete build artifacts from \(displayItems.count) project(s)."))
            print()
            print("Type '\(OutputFormatter.bold("yes"))' to confirm: ", terminator: "")

            guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                  input == "yes" else {
                print()
                print(OutputFormatter.dim("Cleanup cancelled."))
                return EXIT_SUCCESS
            }
        }

        // Execute
        print()
        print(OutputFormatter.bold("Executing cleanup..."))
        print()

        let engine = CleanupEngine()
        let config = CleanupConfig(profiles: [.system])
        let result = engine.apply(plan: plan, config: config)

        // Report
        if result.steps.isEmpty && result.skipped.isEmpty {
            print("  No artifacts were cleaned.")
        } else {
            for step in result.steps where step.success {
                let size = OutputFormatter.formatSizeMB(step.freedMB)
                print("  \(OutputFormatter.green("✓")) \(step.name) (\(size))")
            }
            for step in result.steps where !step.success {
                print("  \(OutputFormatter.red("✗")) \(step.name)")
            }
            for skipped in result.skipped {
                print("  \(OutputFormatter.yellow("⊘")) \(skipped.name) (\(skipped.reason))")
            }
        }

        print()
        if result.totalFreedMB > 0 {
            print("  \(OutputFormatter.bold("Total freed:")) \(OutputFormatter.green(OutputFormatter.formatSizeMB(result.totalFreedMB)))")
        } else {
            print("  \(OutputFormatter.bold("Total freed:")) 0 MB")
        }

        return result.failureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE
    }

    // MARK: - JSON Output

    private static func outputJSON(_ artifacts: [ArtifactItem]) -> Int32 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let totalMB = artifacts.reduce(0) { $0 + $1.sizeMB }

        let output = ArtifactsJSON(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            totalCount: artifacts.count,
            totalSizeMB: totalMB,
            items: artifacts.map { item in
                ArtifactsItem(
                    project: (item.projectPath as NSString).lastPathComponent,
                    projectPath: item.projectPath,
                    artifactName: item.artifactName,
                    artifactPath: item.artifactPath,
                    sizeMB: item.sizeMB,
                    tool: item.type.tool,
                    action: OutputFormatter.actionLabel(item.action),
                    lastModified: ISO8601DateFormatter().string(from: item.lastModified),
                    ageDays: item.ageDays,
                    isRecent: item.isRecent,
                    warning: item.type.warning
                )
            }
        )

        do {
            let data = try encoder.encode(output)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_SUCCESS
        } catch {
            let err = JSONError(command: "artifacts", error: error.localizedDescription, code: "ENCODE_FAILED")
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_FAILURE
        }
    }
}

// MARK: - JSON Schema

struct ArtifactsJSON: Encodable {
    let schemaVersion: String = "1.0.0"
    let command: String = "artifacts"
    let timestamp: String
    let totalCount: Int
    let totalSizeMB: Double
    let items: [ArtifactsItem]
}

struct ArtifactsItem: Encodable {
    /// Project directory name.
    let project: String
    /// Full path to the project directory.
    let projectPath: String
    /// Artifact directory name (e.g. "node_modules").
    let artifactName: String
    /// Full path to the artifact directory.
    let artifactPath: String
    /// Size in megabytes.
    let sizeMB: Double
    /// Tool that produced this artifact.
    let tool: String
    /// Action: "delete" (file deletion).
    let action: String
    /// When the artifact was last modified.
    let lastModified: String
    /// Age in days.
    let ageDays: Int
    /// Whether the artifact was recently modified.
    let isRecent: Bool
    /// Warning message, if any.
    let warning: String?
}
