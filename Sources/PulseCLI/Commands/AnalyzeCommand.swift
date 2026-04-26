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
            print(BuildVersion.cliString())
            print()
            print("Usage: pulse analyze [--json]")
            print()
            print("Scan supported cleanup profiles and estimate reclaimable cache space.")
            print("This is the best first command for new users.")
            print()
            print("Profiles scanned:")
            print(OutputFormatter.command("xcode", description: "DerivedData, Archives, DeviceSupport, Simulators"))
            print(OutputFormatter.command("homebrew", description: "Download cache, old formulae, old casks"))
            print(OutputFormatter.command("node", description: "npm cache, Yarn cache, pnpm store"))
            print(OutputFormatter.command("python", description: "pip, Poetry, and uv caches"))
            print(OutputFormatter.command("bun", description: "Bun install cache"))
            print(OutputFormatter.command("rust", description: "Cargo registry and git caches"))
            print(OutputFormatter.command("claude", description: "Claude Code logs, caches, and session artifacts"))
            print(OutputFormatter.command("cursor", description: "Cursor IDE caches, logs, and workspace storage"))
            print(OutputFormatter.command("installers", description: "Old AI tool installers and archives in Downloads/Desktop"))
            print()
            print("Options:")
            print(OutputFormatter.command("--json", description: "Output as JSON (stable schema for scripting)"))
            return EXIT_SUCCESS
        }

        let jsonOutput = args.contains("--json")
        let allProfiles: Set<CleanupProfile> = [.xcode, .homebrew, .node, .python, .bun, .rust, .claude, .cursor, .installers]
        let config = CleanupConfig(profiles: allProfiles)

        let engine = CleanupEngine()
        let plan: CleanupPlan

        if jsonOutput {
            plan = engine.scan(config: config)
        } else {
            let spinner = OutputFormatter.Spinner(message: "Scanning for cleanup candidates...")
            spinner.start()
            plan = engine.scan(config: config)
            spinner.stop(success: true)
            print()
        }

        if jsonOutput {
            return outputJSON(plan)
        }

        return outputHuman(plan)
    }

    // MARK: - Human Output

    private static func outputHuman(_ plan: CleanupPlan) -> Int32 {
        print(OutputFormatter.bold("Pulse"))

        if plan.items.isEmpty {
            print()
            print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.green("Nothing to clean — all caches are below thresholds.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run '\(OutputFormatter.bold("pulse artifacts"))' to check project build artifacts next.")))
            return EXIT_SUCCESS
        }

        print(OutputFormatter.section("Cleanup Analysis"))
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
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run '\(OutputFormatter.bold("pulse clean"))' to preview cleanup.")))
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run '\(OutputFormatter.bold("pulse clean --profile <name> --apply"))' to execute.")))
        print(OutputFormatter.safetyFootnote())

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
