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
            print(BuildVersion.cliString())
            print()
            print("Usage: pulse audit [--json]")
            print()
            print("Scan for developer-machine maintenance issues such as:")
            print(OutputFormatter.item(OutputFormatter.dot, "stale Xcode simulators and caches"))
            print(OutputFormatter.item(OutputFormatter.dot, "old Xcode Archives"))
            print(OutputFormatter.item(OutputFormatter.dot, "orphaned Homebrew taps"))
            print(OutputFormatter.item(OutputFormatter.dot, "broken symlinks in developer directories"))
            print(OutputFormatter.item(OutputFormatter.dot, "custom Xcode toolchains"))
            print()
            print("Options:")
            print(OutputFormatter.command("--json", description: "Output as JSON (auto-enabled when piped)"))
            return EXIT_SUCCESS
        }

        let scanner = AuditScanner()
        let issues: [AuditIssue]

        if jsonOutput {
            issues = scanner.scan()
        } else {
            let spinner = OutputFormatter.Spinner(message: "Auditing developer environment...")
            spinner.start()
            issues = scanner.scan()
            spinner.stop(success: true)
            print()
        }

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
            print(OutputFormatter.item(OutputFormatter.check, OutputFormatter.green("No issues found. Your developer environment looks good.")))
            return EXIT_SUCCESS
        }

        let criticalCount = issues.filter { $0.severity == .critical }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        let totalReclaimable = issues.compactMap { $0.reclaimableMB }.reduce(0, +)

        print(OutputFormatter.bold("Pulse"))
        print(OutputFormatter.panel(title: "Developer Environment Audit", lines: [
            "Critical issues  \(criticalCount)",
            "Warnings         \(warningCount)",
            "Info             \(infoCount)",
            "Potential reclaim \(OutputFormatter.formatSizeMB(totalReclaimable))",
        ]))

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
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Fix critical and warning items first to keep your developer machine healthy.")))
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run '\(OutputFormatter.bold("pulse artifacts"))' to clean project build artifacts next.")))

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
