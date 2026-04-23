//
//  AnalyzeCommand.swift
//  PulseCLI
//
//  "pulse analyze" — scan all profiles and show what can be cleaned.
//

import Foundation
import PulseCore

enum AnalyzeCommand {

    static func run(_ args: [String]) -> Int32 {
        if args.contains(where: { $0 == "--help" || $0 == "-h" }) {
            print("Usage: pulse analyze [--json]")
            print()
            print("Scan all supported profiles (xcode, homebrew, node) and show")
            print("what can be cleaned, including estimated reclaimable space.")
            print()
            print("Options:")
            print("  --json    Output as JSON (stable schema for scripting)")
            return EXIT_SUCCESS
        }

        let jsonOutput = args.contains("--json")
        let allProfiles: Set<CleanupProfile> = [.xcode, .homebrew, .node]
        let config = CleanupConfig(profiles: allProfiles)

        if !jsonOutput {
            print(OutputFormatter.bold("Pulse"))
            print()
        }

        let engine = CleanupEngine()
        let plan = engine.scan(config: config)

        if jsonOutput {
            return outputJSON(plan)
        }

        return outputHuman(plan)
    }

    // MARK: - Human Output

    private static func outputHuman(_ plan: CleanupPlan) -> Int32 {
        if plan.items.isEmpty {
            print("  Nothing to clean. All caches are below thresholds.")
            return EXIT_SUCCESS
        }

        print(OutputFormatter.bold("Scanning for cleanup candidates..."))
        print()
        print(OutputFormatter.bold("Cleanup Analysis"))
        print(OutputFormatter.dim("Total reclaimable: \(OutputFormatter.formatSizeMB(plan.totalSizeMB)) across \(plan.items.count) item(s)"))
        print()

        // Table
        let headers = ["Item", "Size", "Priority", "Profile"]
        let rows = plan.items.map { item -> [String] in
            [
                item.name,
                OutputFormatter.formatSizeMB(item.sizeMB),
                OutputFormatter.formatPriority(item.priority),
                item.profile.rawValue,
            ]
        }

        print(OutputFormatter.table(headers: headers, rows: rows))

        // Warnings
        let itemsWithWarnings = plan.items.filter { $0.warningMessage != nil }
        if !itemsWithWarnings.isEmpty {
            print()
            for item in itemsWithWarnings {
                print(OutputFormatter.formatWarning(item.warningMessage!))
            }
        }

        // Footer
        print()
        print(OutputFormatter.dim("Run 'pulse clean --dry-run' to preview cleanup."))
        print(OutputFormatter.dim("Run 'pulse clean --profile <name> --apply' to execute."))

        return EXIT_SUCCESS
    }

    // MARK: - JSON Output

    private static func outputJSON(_ plan: CleanupPlan) -> Int32 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let output = AnalyzeJSON(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            totalSizeMB: plan.totalSizeMB,
            itemCount: plan.items.count,
            items: plan.items.map { item in
                AnalyzeItem(
                    name: item.name,
                    sizeMB: item.sizeMB,
                    priority: item.priority.rawValue,
                    profile: item.profile.rawValue,
                    path: item.path,
                    category: item.category.rawValue,
                    action: OutputFormatter.actionLabel(item.action),
                    warning: item.warningMessage,
                    requiresAppClosed: item.requiresAppClosed
                )
            }
        )

        do {
            let data = try encoder.encode(output)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_SUCCESS
        } catch {
            let err = JSONError(command: "analyze", error: error.localizedDescription, code: "ENCODE_FAILED")
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_FAILURE
        }
    }
}

// MARK: - JSON Schema

/// Stable JSON output schema for `pulse analyze --json`.
/// schemaVersion follows semver: major changes on incompatible schema updates.
/// Current: 1.0.0 — initial release.
struct AnalyzeJSON: Encodable {
    /// Schema version, not CLI version. Bumped on incompatible changes.
    let schemaVersion: String = "1.0.0"
    let command: String = "analyze"
    let timestamp: String
    let totalSizeMB: Double
    let itemCount: Int
    let items: [AnalyzeItem]
}

/// A single cleanup candidate from analyze.
/// All fields are stable across schema 1.x minor bumps.
struct AnalyzeItem: Encodable {
    /// Human-readable name of the cleanup item.
    let name: String
    /// Estimated size in megabytes.
    let sizeMB: Double
    /// Priority: "High", "Medium", "Low", or "Optional".
    let priority: String
    /// Profile that owns this item: "xcode", "homebrew", "node", "system".
    let profile: String
    /// File path to the item (may contain ~ for home directory).
    let path: String
    /// Category: "Developer", "Browser", "Applications", "System", "Logs".
    let category: String
    /// Action: "delete" (file deletion) or "command:<cmd>" (run shell command).
    let action: String
    /// Warning message, if any. nil means no warning.
    let warning: String?
    /// Whether this cleanup requires the associated app to be closed.
    let requiresAppClosed: Bool
}

struct JSONError: Encodable {
    let schemaVersion: String
    let command: String
    let error: String
    let code: String

    init(command: String, error: String, code: String) {
        self.schemaVersion = "1.0.0"
        self.command = command
        self.error = error
        self.code = code
    }
}
