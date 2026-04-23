//
//  AuditCommand.swift
//  PulseCLI
//
//  "pulse audit" — scan for developer environment maintenance issues.
//

import Foundation
import PulseCore

enum AuditCommand {

    // MARK: - Run

    static func run(_ args: [String]) -> Int32 {
        let jsonOutput = args.contains("--json")

        if args.contains("--help") || args.contains("-h") {
            print("Usage: pulse audit [--json]")
            print()
            print("Scan for developer environment maintenance issues:")
            print("  - Stale Xcode simulators and caches")
            print("  - Old Xcode Archives")
            print("  - Orphaned Homebrew taps")
            print("  - Broken symlinks in developer directories")
            print("  - Custom Xcode toolchains")
            print()
            print("Options:")
            print("  --json    Output as JSON (auto-enabled when piped)")
            return EXIT_SUCCESS
        }

        let scanner = AuditScanner()
        let issues = scanner.scan()

        if jsonOutput {
            return outputJSON(issues)
        }

        return outputHuman(issues)
    }

    // MARK: - Human Output

    private static func outputHuman(_ issues: [AuditIssue]) -> Int32 {
        if issues.isEmpty {
            print(OutputFormatter.bold("Pulse"))
            print()
            print(OutputFormatter.green("✓ No issues found. Your developer environment looks good."))
            return EXIT_SUCCESS
        }

        print(OutputFormatter.bold("Pulse"))
        print()
        print(OutputFormatter.bold("Developer Environment Audit"))

        let criticalCount = issues.filter { $0.severity == .critical }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        let totalReclaimable = issues.compactMap { $0.reclaimableMB }.reduce(0, +)

        var statusParts: [String] = []
        if criticalCount > 0 { statusParts.append(OutputFormatter.red("\(criticalCount) critical")) }
        if warningCount > 0 { statusParts.append(OutputFormatter.yellow("\(warningCount) warning(s)")) }
        if infoCount > 0 { statusParts.append(OutputFormatter.dim("\(infoCount) info")) }
        print(OutputFormatter.dim(statusParts.joined(separator: " · ")))

        if totalReclaimable > 0 {
            print(OutputFormatter.dim("Potential reclaimable: \(OutputFormatter.formatSizeMB(totalReclaimable))"))
        }

        print()

        // Group by category
        let grouped = Dictionary(grouping: issues, by: { $0.category })
        let categoryOrder: [AuditIssue.Category] = [.xcode, .homebrew, .toolchains, .symlinks, .general]

        for category in categoryOrder {
            guard let categoryIssues = grouped[category] else { continue }

            print(OutputFormatter.bold(category.rawValue))
            print()

            for issue in categoryIssues.sorted(by: { $0.severity.rawValue < $1.severity.rawValue }) {
                let icon = severityIcon(issue.severity)
                print("  \(icon) \(OutputFormatter.bold(issue.title))")

                // Indent description (handle multi-line)
                for line in issue.description.components(separatedBy: "\n") {
                    print("    \(OutputFormatter.dim(line))")
                }

                if let reclaimable = issue.reclaimableMB, reclaimable > 0 {
                    print("    \(OutputFormatter.yellow("~\(OutputFormatter.formatSizeMB(reclaimable)) reclaimable"))")
                }

                print()
            }
        }

        // Footer
        print(OutputFormatter.dim("Fix critical and warning items to optimize your dev environment."))
        print(OutputFormatter.dim("Run 'pulse artifacts' to clean project build artifacts."))

        return EXIT_SUCCESS
    }

    private static func severityIcon(_ severity: AuditIssue.Severity) -> String {
        switch severity {
        case .critical: return OutputFormatter.red("✗")
        case .warning: return OutputFormatter.yellow("!")
        case .info: return OutputFormatter.dim("•")
        }
    }

    // MARK: - JSON Output

    private static func outputJSON(_ issues: [AuditIssue]) -> Int32 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let totalReclaimable = issues.compactMap { $0.reclaimableMB }.reduce(0, +)

        let output = AuditJSON(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            totalIssues: issues.count,
            criticalCount: issues.filter { $0.severity == .critical }.count,
            warningCount: issues.filter { $0.severity == .warning }.count,
            infoCount: issues.filter { $0.severity == .info }.count,
            totalReclaimableMB: totalReclaimable,
            issues: issues.map { issue in
                AuditJSONIssue(
                    title: issue.title,
                    description: issue.description,
                    reclaimableMB: issue.reclaimableMB,
                    severity: issue.severity.rawValue,
                    category: issue.category.rawValue,
                    path: issue.path
                )
            }
        )

        do {
            let data = try encoder.encode(output)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_SUCCESS
        } catch {
            let err = JSONError(command: "audit", error: error.localizedDescription, code: "ENCODE_FAILED")
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
            return EXIT_FAILURE
        }
    }
}

// MARK: - JSON Schema

struct AuditJSON: Encodable {
    let schemaVersion: String = "1.0.0"
    let command: String = "audit"
    let timestamp: String
    let totalIssues: Int
    let criticalCount: Int
    let warningCount: Int
    let infoCount: Int
    let totalReclaimableMB: Double
    let issues: [AuditJSONIssue]
}

struct AuditJSONIssue: Encodable {
    let title: String
    let description: String
    let reclaimableMB: Double?
    let severity: String
    let category: String
    let path: String?
}
