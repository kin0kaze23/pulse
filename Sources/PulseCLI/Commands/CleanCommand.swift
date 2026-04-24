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
        "python": .python,
    ]

    // MARK: - Run

    static func run(_ args: [String]) -> Int32 {
        let parsed = parseArgs(args)

        switch parsed {
        case .help:
            print(BuildVersion.cliString())
            print()
            print("Usage:")
            print("  pulse clean")
            print("  pulse clean --dry-run")
            print("  pulse clean --profile <name> --dry-run")
            print("  pulse clean --profile <name> --apply")
            print()
            print("Preview-first cleanup for supported profiles.")
            print("Running 'pulse clean' with no action defaults to a safe preview.")
            print("Use --dry-run first, then --apply when the preview looks right.")
            print()
            print("Options:")
            print(OutputFormatter.command("--json", description: "Output as JSON (stable schema for scripting)"))
            print(OutputFormatter.command("--yes, -y, --force", description: "Skip confirmation prompt (for CI/CD automation)"))
            return EXIT_SUCCESS

        case .dryRun(let profile, let json, let guided):
            return runDryRun(profile: profile, json: json, guided: guided)

        case .apply(let profile, let force):
            return runApply(profile: profile, force: force)
        }
    }

    // MARK: - Argument Parsing

    private enum ParsedArgs {
        case help
        case dryRun(profile: CleanupProfile?, json: Bool, guided: Bool)
        case apply(profile: CleanupProfile?, force: Bool)
    }

    private static func parseArgs(_ args: [String]) -> ParsedArgs {
        var profileName: String?
        var action: ParsedArgs?
        var json = false
        var force = false
        let guided = !args.contains("--dry-run") && !args.contains("--apply")

        // First pass: detect --json and --yes anywhere
        json = args.contains("--json")
        force = args.contains("--yes") || args.contains("-y") || args.contains("--force")

        var i = 0
        while i < args.count {
            switch args[i] {
            case "--help", "-h":
                return .help
            case "--json", "--yes", "-y", "--force":
                break  // Already handled above
            case "--profile":
                i += 1
                if i < args.count {
                    profileName = args[i]
                }
            case "--dry-run":
                if let name = profileName, let profile = supportedProfiles[name] {
                    action = .dryRun(profile: profile, json: json, guided: false)
                } else if profileName == nil {
                    action = .dryRun(profile: nil, json: json, guided: false)
                } else {
                    print(OutputFormatter.red("Error: Unsupported profile '\(profileName!)'"))
                    print("Supported profiles: \(supportedProfiles.keys.sorted().joined(separator: ", "))")
                    return .help
                }
            case "--apply":
                if let name = profileName, let profile = supportedProfiles[name] {
                    action = .apply(profile: profile, force: force)
                } else if profileName == nil {
                    action = .apply(profile: nil, force: force)
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

        if let action { return action }

        if let name = profileName, let profile = supportedProfiles[name] {
            return .dryRun(profile: profile, json: json, guided: guided)
        } else if let name = profileName {
            print(OutputFormatter.red("Error: Unsupported profile '\(name)'"))
            print("Supported profiles: \(supportedProfiles.keys.sorted().joined(separator: ", "))")
            return .help
        }

        return .dryRun(profile: nil, json: json, guided: guided)
    }

    // MARK: - Dry Run

    private static func runDryRun(profile: CleanupProfile?, json: Bool, guided: Bool) -> Int32 {
        let profiles: Set<CleanupProfile>
        if let profile = profile {
            profiles = [profile]
        } else {
            profiles = [.xcode, .homebrew, .node, .python]
        }

        let config = CleanupConfig(profiles: profiles)
        let engine = CleanupEngine()
        let plan: CleanupPlan

        if json {
            plan = engine.scan(config: config)
        } else {
            let spinner = OutputFormatter.Spinner(message: "Preparing cleanup preview...")
            spinner.start()
            plan = engine.scan(config: config)
            spinner.stop(success: true)
            print()
        }

        if json {
            return outputDryRunJSON(plan, profile: profile)
        }

        return outputDryRunHuman(plan, profile: profile, guided: guided)
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
            let err = CleanJSONError(error: error.localizedDescription)
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_FAILURE
        }
    }

    // MARK: - Dry Run Human

    private enum InteractiveChoice {
        case recommended
        case all
        case profile(CleanupProfile)
        case cancel
    }

    private static func recommendedItems(from items: [CleanupPlan.CleanupItem]) -> [CleanupPlan.CleanupItem] {
        items.filter {
            $0.warningMessage == nil && !$0.requiresAppClosed && $0.priority != .low && $0.skipReason == nil
        }
    }

    private static func reviewItems(from items: [CleanupPlan.CleanupItem]) -> [CleanupPlan.CleanupItem] {
        items.filter { item in
            !(item.warningMessage == nil && !item.requiresAppClosed && item.priority != .low && item.skipReason == nil)
        }
    }

    private static func totalSize(of items: [CleanupPlan.CleanupItem]) -> Double {
        items.reduce(0) { $0 + $1.sizeMB }
    }

    private static func profileSummary(from items: [CleanupPlan.CleanupItem]) -> String {
        let grouped = Dictionary(grouping: items, by: { $0.profile.rawValue })
        return grouped.keys.sorted().map { key in
            let count = grouped[key]?.count ?? 0
            return "\(key)(\(count))"
        }.joined(separator: " · ")
    }

    private static func renderGroup(title: String, icon: String, items: [CleanupPlan.CleanupItem]) {
        guard !items.isEmpty else { return }
        print(OutputFormatter.section(title))
        for item in items {
            let size = OutputFormatter.formatSizeMB(item.sizeMB)
            let detail = item.warningMessage ?? actionDescription(for: item)
            print(OutputFormatter.item(icon, "\(item.name) — \(size)"))
            print(OutputFormatter.item(OutputFormatter.dot, OutputFormatter.dim(detail)))
        }
    }

    private static func actionDescription(for item: CleanupPlan.CleanupItem) -> String {
        switch item.action {
        case .file:
            return item.requiresAppClosed ? "Close associated app before cleaning" : "Safe file-based cleanup"
        case .command(let cmd):
            return cmd
        }
    }

    private static func subplan(from items: [CleanupPlan.CleanupItem]) -> CleanupPlan {
        CleanupPlan(items: items, totalSizeMB: totalSize(of: items))
    }

    private static func promptInteractiveChoice(plan: CleanupPlan, currentProfile: CleanupProfile?) -> InteractiveChoice {
        print()
        print(OutputFormatter.section("Next action"))
        print(OutputFormatter.item(OutputFormatter.arrow, "Press Enter to clean recommended items"))
        print(OutputFormatter.item(OutputFormatter.arrow, "Press p to choose a profile"))
        print(OutputFormatter.item(OutputFormatter.arrow, "Press a to clean everything shown"))
        print(OutputFormatter.item(OutputFormatter.arrow, "Press q to cancel"))
        print()
        print("Choice: ", terminator: "")

        let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "q"
        switch input {
        case "": return .recommended
        case "a": return .all
        case "p":
            return promptProfileChoice(currentProfile: currentProfile)
        default:
            return .cancel
        }
    }

    private static func promptProfileChoice(currentProfile: CleanupProfile?) -> InteractiveChoice {
        print()
        print(OutputFormatter.section("Choose profile"))
        let profiles = supportedProfiles.keys.sorted()
        for (index, key) in profiles.enumerated() {
            let suffix = currentProfile?.rawValue == key ? " (current)" : ""
            print(OutputFormatter.item(OutputFormatter.dot, "[\(index + 1)] \(key)\(suffix)"))
        }
        print(OutputFormatter.item(OutputFormatter.dot, "[q] cancel"))
        print()
        print("Profile: ", terminator: "")

        let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "q"
        if input == "q" { return .cancel }
        if let index = Int(input), profiles.indices.contains(index - 1), let profile = supportedProfiles[profiles[index - 1]] {
            return .profile(profile)
        }
        return .cancel
    }

    private static func executeInteractive(plan: CleanupPlan, scopeLabel: String, requireStrongConfirmation: Bool) -> Int32 {
        print()
        if requireStrongConfirmation {
            print(OutputFormatter.yellow("This will clean all items shown for \(scopeLabel)."))
            print(OutputFormatter.dim("Type CLEAN ALL to continue: "), terminator: "")
            let input = readLine()?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard input == "CLEAN ALL" else {
                print()
                print(OutputFormatter.dim("Cleanup cancelled."))
                return EXIT_SUCCESS
            }
        }

        print()
        print(OutputFormatter.bold("Executing cleanup..."))
        print()

        let profiles = Set(plan.items.map(\.profile))
        let config = CleanupConfig(profiles: profiles)
        let result = CleanupEngine().apply(plan: plan, config: config)
        return outputApplyResult(result)
    }

    private static func outputApplyResult(_ result: CleanupResult) -> Int32 {
        if result.steps.isEmpty && result.skipped.isEmpty {
            print("  No items were cleaned.")
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

    private static func outputDryRunHuman(_ plan: CleanupPlan, profile: CleanupProfile?, guided: Bool) -> Int32 {
        let profileLabel = profile.map { $0.rawValue } ?? "all profiles"

        print(OutputFormatter.bold("Pulse"))

        if plan.items.isEmpty {
            print(OutputFormatter.section("Cleanup Preview — \(profileLabel)"))
            print()
            print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.green("Nothing to clean — all caches are below thresholds.")))
            return EXIT_SUCCESS
        }

        let recommended = recommendedItems(from: plan.items)
        let review = reviewItems(from: plan.items)
        let summaryPanel = OutputFormatter.panel(title: "Cleanup Preview — \(profileLabel)", lines: [
            "Reclaimable now  \(OutputFormatter.formatSizeMB(plan.totalSizeMB))",
            "Recommended     \(recommended.count) item(s) · \(OutputFormatter.formatSizeMB(totalSize(of: recommended)))",
            "Review first    \(review.count) item(s) · \(OutputFormatter.formatSizeMB(totalSize(of: review)))",
            "Profiles        \(profileSummary(from: plan.items))",
        ])
        print(summaryPanel)

        renderGroup(title: "Recommended", icon: OutputFormatter.check, items: recommended)
        if !review.isEmpty {
            renderGroup(title: "Review before cleaning", icon: OutputFormatter.warn, items: review)
        }

        print()
        print(OutputFormatter.safetyFootnote())

        guard guided, isatty(fileno(stdout)) != 0 else {
            print(OutputFormatter.actionFooter([
                "Run 'pulse clean --apply --yes' for automation",
                "Run 'pulse clean --profile <name>' to focus one profile",
            ]))
            return EXIT_SUCCESS
        }

        switch promptInteractiveChoice(plan: plan, currentProfile: profile) {
        case .recommended:
            if recommended.isEmpty {
                print()
                print(OutputFormatter.item(OutputFormatter.warn, OutputFormatter.yellow("No recommended items available. Choose a profile or clean everything shown.")))
                return EXIT_SUCCESS
            }
            return executeInteractive(plan: subplan(from: recommended), scopeLabel: "recommended items", requireStrongConfirmation: false)
        case .all:
            return executeInteractive(plan: plan, scopeLabel: profileLabel, requireStrongConfirmation: true)
        case .profile(let selectedProfile):
            return runDryRun(profile: selectedProfile, json: false, guided: true)
        case .cancel:
            print()
            print(OutputFormatter.dim("Cleanup cancelled."))
            return EXIT_SUCCESS
        }
    }

    // MARK: - Apply

    private static func runApply(profile: CleanupProfile?, force: Bool) -> Int32 {
        let profiles: Set<CleanupProfile>
        let profileLabel: String
        if let profile = profile {
            profiles = [profile]
            profileLabel = profile.rawValue
        } else {
            profiles = [.xcode, .homebrew, .node, .python]
            profileLabel = "all profiles"
        }

        let config = CleanupConfig(profiles: profiles)
        let engine = CleanupEngine()

        // Preview first
        let spinner = OutputFormatter.Spinner(message: "Preparing cleanup plan...")
        spinner.start()
        let plan = engine.scan(config: config)
        spinner.stop(success: true)
        print()

        if plan.items.isEmpty {
            print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.green("Nothing to clean — all caches are below thresholds.")))
            return EXIT_SUCCESS
        }

        print(OutputFormatter.bold("Pulse"))
        print(OutputFormatter.section("Cleanup Preview — \(profileLabel)"))
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

        // Confirmation (skip if --yes / --force)
        if !force {
            print()
            print(OutputFormatter.yellow("This action will remove cleanup targets for \(profileLabel)."))
            if plan.items.contains(where: { $0.warningMessage != nil }) {
                print(OutputFormatter.yellow("Some items have warnings — review before proceeding."))
            }
            print(OutputFormatter.safetyFootnote())
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

        let result = engine.apply(plan: plan, config: config)

        // Report
        if result.steps.isEmpty && result.skipped.isEmpty {
            print("  No items were cleaned.")
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
