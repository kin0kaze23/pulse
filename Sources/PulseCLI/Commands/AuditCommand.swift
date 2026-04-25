//
//  AuditCommand.swift
//  PulseCLI
//
//  "pulse audit" — scan for developer environment maintenance issues.
//

import Foundation
import PulseCore

enum AuditCommand {

    private enum Mode: String {
        case general
        case indexBloat = "index-bloat"
        case agentData = "agent-data"
        case models
    }

    // MARK: - Run

    static func run(_ args: [String]) -> Int32 {
        let jsonOutput = args.contains("--json")
        let mode = parseMode(args)

        if args.contains("--help") || args.contains("-h") {
            print(BuildVersion.cliString())
            print()
            print("Usage: pulse audit [index-bloat|agent-data|models] [--json]")
            print()
            print("Scan for developer-machine maintenance issues such as:")
            print(OutputFormatter.item(OutputFormatter.dot, "stale Xcode simulators and caches"))
            print(OutputFormatter.item(OutputFormatter.dot, "old Xcode Archives"))
            print(OutputFormatter.item(OutputFormatter.dot, "orphaned Homebrew taps"))
            print(OutputFormatter.item(OutputFormatter.dot, "broken symlinks in developer directories"))
            print(OutputFormatter.item(OutputFormatter.dot, "custom Xcode toolchains"))
            print(OutputFormatter.item(OutputFormatter.dot, "AI workstation index bloat and agent-data retention"))
            print()
            print("Options:")
            print(OutputFormatter.command("index-bloat", description: "Audit repos that are likely slowing Cursor/VS Code indexing"))
            print(OutputFormatter.command("agent-data", description: "Audit Claude/Cursor data retention and cache sprawl"))
            print(OutputFormatter.command("models", description: "Audit Ollama / LM Studio model storage and duplication risk"))
            print(OutputFormatter.command("--json", description: "Output as JSON (auto-enabled when piped)"))
            return EXIT_SUCCESS
        }

        let issues: [AuditIssue]

        if jsonOutput {
            issues = scanIssues(for: mode)
        } else {
            let spinner = OutputFormatter.Spinner(message: spinnerMessage(for: mode))
            spinner.start()
            issues = scanIssues(for: mode)
            spinner.stop(success: true)
            print()
        }

        if jsonOutput {
            return outputJSON(issues, mode: mode)
        }

        return outputHuman(issues, mode: mode)
    }

    private static func parseMode(_ args: [String]) -> Mode {
        if args.contains(Mode.indexBloat.rawValue) { return .indexBloat }
        if args.contains(Mode.agentData.rawValue) { return .agentData }
        if args.contains(Mode.models.rawValue) { return .models }
        return .general
    }

    private static func scanIssues(for mode: Mode) -> [AuditIssue] {
        switch mode {
        case .general:
            return AuditScanner().scan()
        case .indexBloat:
            return IndexBloatAuditScanner().scan()
        case .agentData:
            return AgentDataAuditScanner().scan()
        case .models:
            return ModelsAuditScanner().scan()
        }
    }

    private static func spinnerMessage(for mode: Mode) -> String {
        switch mode {
        case .general: return "Auditing developer environment..."
        case .indexBloat: return "Auditing indexing bloat risks..."
        case .agentData: return "Auditing agent-data retention..."
        case .models: return "Auditing local model storage..."
        }
    }

    // MARK: - Human Output

    private static func outputHuman(_ issues: [AuditIssue], mode: Mode) -> Int32 {
        if issues.isEmpty {
            print(OutputFormatter.bold("Pulse"))
            print()
            let message: String
            switch mode {
            case .general: message = "No issues found. Your developer environment looks good."
            case .indexBloat: message = "No obvious indexing bloat found in scanned projects."
            case .agentData: message = "No significant Claude/Cursor data retention issues found."
            case .models: message = "No significant local model storage issues found."
            }
            print(OutputFormatter.item(OutputFormatter.check, OutputFormatter.green(message)))
            return EXIT_SUCCESS
        }

        let criticalCount = issues.filter { $0.severity == .critical }.count
        let warningCount = issues.filter { $0.severity == .warning }.count
        let infoCount = issues.filter { $0.severity == .info }.count
        let totalReclaimable = issues.compactMap { $0.reclaimableMB }.reduce(0, +)

        let title: String
        switch mode {
        case .general: title = "Developer Environment Audit"
        case .indexBloat: title = "Index Bloat Audit"
        case .agentData: title = "Agent Data Audit"
        case .models: title = "Model Storage Audit"
        }

        print(OutputFormatter.bold("Pulse"))
        print(OutputFormatter.panel(title: title, lines: [
            "Critical issues  \(criticalCount)",
            "Warnings         \(warningCount)",
            "Info             \(infoCount)",
            "Potential reclaim \(OutputFormatter.formatSizeMB(totalReclaimable))",
        ]))

        // Group by category
        let grouped = Dictionary(grouping: issues, by: { $0.category })
        let categoryOrder: [AuditIssue.Category] = [.aiWorkspace, .xcode, .homebrew, .toolchains, .symlinks, .general]

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
        switch mode {
        case .general:
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Fix critical and warning items first to keep your developer machine healthy.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run '\(OutputFormatter.bold("pulse artifacts"))' to clean project build artifacts next.")))
        case .indexBloat:
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Add .cursorignore patterns for generated folders before your next coding session.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run '\(OutputFormatter.bold("pulse artifacts"))' to remove old generated folders.")))
        case .agentData:
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Use '\(OutputFormatter.bold("pulse clean --profile claude"))' or '\(OutputFormatter.bold("pulse clean --profile cursor"))' to review cleanup targets.")))
        case .models:
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Review large Ollama or LM Studio model directories before deleting anything.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("If both tools are large, check whether the same models are stored twice.")))
        }

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

    private static func outputJSON(_ issues: [AuditIssue], mode: Mode) -> Int32 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let totalReclaimable = issues.compactMap { $0.reclaimableMB }.reduce(0, +)

        let output = AuditJSON(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            mode: mode.rawValue,
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
    let mode: String
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
