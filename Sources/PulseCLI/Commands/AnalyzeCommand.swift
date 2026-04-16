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
            print("Usage: pulse analyze")
            print()
            print("Scan all supported profiles (xcode, homebrew, node) and show")
            print("what can be cleaned, including estimated reclaimable space.")
            return EXIT_SUCCESS
        }

        let allProfiles: Set<CleanupProfile> = [.xcode, .homebrew, .node]
        let config = CleanupConfig(profiles: allProfiles)

        print(OutputFormatter.bold("Scanning for cleanup candidates..."))
        print()

        let engine = CleanupEngine()
        let plan = engine.scan(config: config)

        if plan.items.isEmpty {
            print("  Nothing to clean. All caches are below thresholds.")
            return EXIT_SUCCESS
        }

        // Header
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
                profileLabel(for: item),
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

    private static func profileLabel(for item: CleanupPlan.CleanupItem) -> String {
        // Determine profile from item path/name
        if case .command = item.action {
            return "homebrew"
        }
        let xcodePaths = ["DerivedData", "Archives", "DeviceSupport", "CoreSimulator"]
        if xcodePaths.contains(where: { item.path.contains($0) }) {
            return "xcode"
        }
        let nodePaths = [".npm", "Yarn", "pnpm"]
        if nodePaths.contains(where: { item.path.contains($0) }) {
            return "node"
        }
        return "unknown"
    }
}
