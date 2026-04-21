//
//  CleanCommand.swift
//  PulseCLI
//
//  "pulse clean" — preview or execute cleanup operations.
//

import Foundation
import PulseCore

enum CleanCommand {

    // MARK: - Supported Profiles

    private static let supportedProfiles: [String: CleanupProfile] = [
        "xcode": .xcode,
        "homebrew": .homebrew,
        "node": .node,
    ]

    // MARK: - Run

    static func run(_ args: [String]) -> Int32 {
        let parsed = parseArgs(args)

        switch parsed {
        case .help:
            print("Usage:")
            print("  pulse clean --dry-run                  Preview all profiles")
            print("  pulse clean --profile <name> --dry-run Preview specific profile")
            print("  pulse clean --profile <name> --apply   Execute cleanup")
            print()
            print("Options:")
            print("  --json    Output as JSON (stable schema for scripting)")
            return EXIT_SUCCESS

        case .missingAction:
            print(OutputFormatter.red("Error: Specify --dry-run or --apply"))
            print()
            print(OutputFormatter.dim("Run 'pulse clean --help' for usage."))
            return EXIT_FAILURE

        case .dryRun(let profile, let json):
            return runDryRun(profile: profile, json: json)

        case .apply(let profile):
            return runApply(profile: profile)
        }
    }

    // MARK: - Argument Parsing

    private enum ParsedArgs {
        case help
        case missingAction
        case dryRun(profile: CleanupProfile?, json: Bool)
        case apply(profile: CleanupProfile?)
    }

    private static func parseArgs(_ args: [String]) -> ParsedArgs {
        var profileName: String?
        var action: ParsedArgs?
        var json = false

        // First pass: detect --json anywhere
        json = args.contains("--json")

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--help", "-h":
                return .help
            case "--json":
                break  // Already handled above
            case "--profile":
                i += 1
                if i < args.count {
                    profileName = args[i]
                }
            case "--dry-run":
                if let name = profileName, let profile = supportedProfiles[name] {
                    action = .dryRun(profile: profile, json: json)
                } else if profileName == nil {
                    action = .dryRun(profile: nil, json: json)
                } else {
                    print(OutputFormatter.red("Error: Unsupported profile '\(profileName!)'"))
                    print("Supported profiles: \(supportedProfiles.keys.sorted().joined(separator: ", "))")
                    return .help
                }
            case "--apply":
                if let name = profileName, let profile = supportedProfiles[name] {
                    action = .apply(profile: profile)
                } else if profileName == nil {
                    action = .apply(profile: nil)
                } else {
                    print(OutputFormatter.red("Error: Unsupported profile '\(profileName!)'"))
                    print("Supported profiles: \(supportedProfiles.keys.sorted().joined(separator: ", "))")
                    return .help
                }
            default:
                break
            }
            i += 1
        }

        return action ?? .missingAction
    }

    // MARK: - Dry Run

    private static func runDryRun(profile: CleanupProfile?, json: Bool) -> Int32 {
        let profiles: Set<CleanupProfile>
        if let profile = profile {
            profiles = [profile]
        } else {
            profiles = [.xcode, .homebrew, .node]
        }

        let config = CleanupConfig(profiles: profiles)
        let engine = CleanupEngine()
        let plan = engine.scan(config: config)

        if json {
            return outputDryRunJSON(plan, profile: profile)
        }

        return outputDryRunHuman(plan, profile: profile)
    }

    // MARK: - Dry Run JSON

    private static func outputDryRunJSON(_ plan: CleanupPlan, profile: CleanupProfile?) -> Int32 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let output = CleanDryRunJSON(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            profile: profile?.rawValue ?? "all",
            totalSizeMB: plan.totalSizeMB,
            itemCount: plan.items.count,
            items: plan.items.map { item in
                CleanDryRunItem(
                    name: item.name,
                    sizeMB: item.sizeMB,
                    priority: item.priority.rawValue,
                    profile: item.profile.rawValue,
                    path: item.path,
                    category: item.category.rawValue,
                    action: actionLabel(item.action),
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
            let err = CleanJSONError(error: error.localizedDescription)
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_FAILURE
        }
    }

    /// Stable action label convention:
    ///   "delete" — file deletion
    ///   "command:<cmd>" — shell command to run
    ///   The "command:" prefix allows scripts to split on first ":" to get the command.
    private static func actionLabel(_ action: CleanupAction) -> String {
        switch action {
        case .file:
            return "delete"
        case .command(let cmd):
            return "command:\(cmd)"
        }
    }

    // MARK: - Dry Run Human

    private static func outputDryRunHuman(_ plan: CleanupPlan, profile: CleanupProfile?) -> Int32 {
        let profileLabel = profile.map { $0.rawValue } ?? "all profiles"

        print(OutputFormatter.bold("Dry Run — \(profileLabel)"))
        print()

        if plan.items.isEmpty {
            print("  Nothing to clean. All caches are below thresholds.")
            return EXIT_SUCCESS
        }

        // Table
        let headers = ["Item", "Size", "Priority", "Action"]
        let rows = plan.items.map { item -> [String] in
            let actionText: String
            switch item.action {
            case .file:
                actionText = "delete"
            case .command(let cmd):
                actionText = String(cmd.prefix(30))
            }
            return [
                item.name,
                OutputFormatter.formatSizeMB(item.sizeMB),
                OutputFormatter.formatPriority(item.priority),
                actionText,
            ]
        }

        print(OutputFormatter.table(headers: headers, rows: rows))

        // Summary
        print()
        print("  \(OutputFormatter.bold("Total reclaimable:")) \(OutputFormatter.formatSizeMB(plan.totalSizeMB))")
        print("  \(OutputFormatter.bold("Items:")) \(plan.items.count)")

        // Warnings
        let itemsWithWarnings = plan.items.filter { $0.warningMessage != nil }
        if !itemsWithWarnings.isEmpty {
            print()
            for item in itemsWithWarnings {
                print(OutputFormatter.formatWarning(item.warningMessage!))
            }
        }

        print()
        print(OutputFormatter.dim("To execute this cleanup, run:"))
        if let profile = profile {
            print(OutputFormatter.dim("  pulse clean --profile \(profile.rawValue) --apply"))
        } else {
            print(OutputFormatter.dim("  pulse clean --profile <name> --apply"))
        }

        return EXIT_SUCCESS
    }

    // MARK: - Apply

    private static func runApply(profile: CleanupProfile?) -> Int32 {
        let profiles: Set<CleanupProfile>
        let profileLabel: String
        if let profile = profile {
            profiles = [profile]
            profileLabel = profile.rawValue
        } else {
            profiles = [.xcode, .homebrew, .node]
            profileLabel = "all profiles"
        }

        let config = CleanupConfig(profiles: profiles)
        let engine = CleanupEngine()

        // Preview first
        let plan = engine.scan(config: config)

        if plan.items.isEmpty {
            print("  Nothing to clean. All caches are below thresholds.")
            return EXIT_SUCCESS
        }

        print(OutputFormatter.bold("Cleanup Preview — \(profileLabel)"))
        print()

        let headers = ["Item", "Size", "Action"]
        let rows = plan.items.map { item -> [String] in
            let actionText: String
            switch item.action {
            case .file:
                actionText = "delete"
            case .command(let cmd):
                actionText = String(cmd.prefix(30))
            }
            return [
                item.name,
                OutputFormatter.formatSizeMB(item.sizeMB),
                actionText,
            ]
        }

        print(OutputFormatter.table(headers: headers, rows: rows))
        print()
        print("  \(OutputFormatter.bold("Total reclaimable:")) \(OutputFormatter.formatSizeMB(plan.totalSizeMB))")

        // Warnings
        let itemsWithWarnings = plan.items.filter { $0.warningMessage != nil }
        if !itemsWithWarnings.isEmpty {
            print()
            for item in itemsWithWarnings {
                print(OutputFormatter.formatWarning(item.warningMessage!))
            }
        }

        // Confirmation
        print()
        print(OutputFormatter.yellow("This action will permanently clean \(profileLabel)."))
        if plan.items.contains(where: { $0.warningMessage != nil }) {
            print(OutputFormatter.yellow("Some items have warnings — review before proceeding."))
        }
        print()
        print("Type '\(OutputFormatter.bold("yes"))' to confirm: ", terminator: "")

        guard let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              input == "yes" else {
            print()
            print(OutputFormatter.dim("Cleanup cancelled."))
            return EXIT_SUCCESS
        }

        // Execute
        print()
        print(OutputFormatter.bold("Executing cleanup..."))
        print()

        let result = engine.apply(plan: plan, config: config)

        // Report
        if result.steps.isEmpty && result.skipped.isEmpty {
            print("  No items were cleaned.")
        } else {
            for step in result.steps where step.success {
                let size = OutputFormatter.formatSizeMB(step.freedMB)
                print("  \(OutputFormatter.green("Cleaned:")) \(step.name) (\(size))")
            }
            for step in result.steps where !step.success {
                print("  \(OutputFormatter.red("Failed:")) \(step.name)")
            }
            for skipped in result.skipped {
                print("  \(OutputFormatter.yellow("Skipped:")) \(skipped.name) (\(skipped.reason))")
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
}

// MARK: - JSON Schema

/// Stable JSON output schema for `pulse clean --dry-run --json`.
/// schemaVersion follows semver: major changes on incompatible schema updates.
/// Current: 1.0.0 — initial release.
struct CleanDryRunJSON: Encodable {
    /// Schema version, not CLI version. Bumped on incompatible changes.
    let schemaVersion: String = "1.0.0"
    let command: String = "clean"
    let mode: String = "dry-run"
    let timestamp: String
    /// Which profile was targeted, or "all".
    let profile: String
    let totalSizeMB: Double
    let itemCount: Int
    let items: [CleanDryRunItem]
}

/// A single cleanup candidate from clean --dry-run.
/// All fields are stable across schema 1.x minor bumps.
struct CleanDryRunItem: Encodable {
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
    /// Action: "delete" (file deletion) or the shell command to run.
    let action: String
    /// Warning message, if any. nil means no warning.
    let warning: String?
    /// Whether this cleanup requires the associated app to be closed.
    let requiresAppClosed: Bool
}

/// Error response for clean command JSON.
struct CleanJSONError: Encodable {
    let schemaVersion: String
    let command: String
    let error: String
    let code: String

    init(error: String) {
        self.schemaVersion = "1.0.0"
        self.command = "clean"
        self.error = error
        self.code = "ENCODE_FAILED"
    }
}
