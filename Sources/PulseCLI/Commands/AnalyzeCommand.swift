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
            version: 1,
            command: "analyze",
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
                    action: actionLabel(item.action),
                    warning: item.warningMessage
                )
            }
        )

        do {
            let data = try encoder.encode(output)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_SUCCESS
        } catch {
            let err = JSONError(error: error.localizedDescription)
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_FAILURE
        }
    }

    private static func actionLabel(_ action: CleanupAction) -> String {
        switch action {
        case .file:
            return "file"
        case .command(let cmd):
            return "command:\(cmd)"
        }
    }
}

// MARK: - JSON Schema

/// Stable JSON output schema for `pulse analyze --json`.
/// Version is bumped when the schema changes incompatibly.
struct AnalyzeJSON: Encodable {
    let version: Int
    let command: String
    let timestamp: String
    let totalSizeMB: Double
    let itemCount: Int
    let items: [AnalyzeItem]
}

struct AnalyzeItem: Encodable {
    let name: String
    let sizeMB: Double
    let priority: String
    let profile: String
    let path: String
    let category: String
    let action: String
    let warning: String?
}

struct JSONError: Encodable {
    let version: Int = 1
    let error: String
}
