//
//  main.swift
//  PulseCLI
//
//  Simplified entry point: one command does everything.
//

import Foundation
import PulseCore

// MARK: - Auto JSON Detection

private func autoJsonArgs(_ args: [String]) -> [String] {
    let isTTY = isatty(fileno(stdout)) != 0
    guard !isTTY, !args.contains("--json") else { return Array(args) }
    return Array(args) + ["--json"]
}

// MARK: - Unified Pulse Runner

private func runUnified() -> Int32 {
    // Hero Header
    print(OutputFormatter.bold("✨") + " " + OutputFormatter.bold("Pulse"))
    print(OutputFormatter.dim("AI Workstation Cleanup — Safe, Preview-First"))
    print()

    // Phase 1: Scan
    let spinner = OutputFormatter.Spinner(message: "Scanning your AI workstation...")
    spinner.start()

    let allProfiles: Set<CleanupProfile> = [.xcode, .homebrew, .node, .python, .bun, .rust, .claude, .cursor, .installers]
    let config = CleanupConfig(profiles: allProfiles)
    let plan = CleanupEngine().scan(config: config)

    spinner.stop(success: true)

    if plan.items.isEmpty {
        print()
        print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.green("Your AI workstation looks clean!")))
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Run 'pulse artifacts' to check project build junk.")))
        return EXIT_SUCCESS
    }

    // Phase 2: Show summary (Dashboard)
    let recommended = plan.items.filter { item in
        item.warningMessage == nil && !item.requiresAppClosed && item.priority != .low && item.skipReason == nil
    }
    let review = plan.items.filter { item in !recommended.contains { $0.name == item.name && $0.path == item.path } }

    print()
    print(OutputFormatter.panel(title: "✨ Found " + OutputFormatter.formatSizeMB(plan.totalSizeMB) + " to clean", lines: [
        "\(OutputFormatter.green("✓")) Recommended: \(recommended.count) items (\(OutputFormatter.formatSizeMB(recommended.reduce(0) { $0 + $1.sizeMB })))",
        "\(OutputFormatter.yellow("⚠")) Review: \(review.count) items (\(OutputFormatter.formatSizeMB(review.reduce(0) { $0 + $1.sizeMB })))",
    ]))

    // Show recommended items
    if !recommended.isEmpty {
        print()
        print(OutputFormatter.section("Recommended (Safe to Clean)"))
        for item in recommended {
            print(OutputFormatter.item(OutputFormatter.check, "\(item.name) — \(OutputFormatter.formatSizeMB(item.sizeMB))"))
        }
    }

    // Show review items
    if !review.isEmpty {
        print()
        print(OutputFormatter.section("Review Before Cleaning"))
        for item in review {
            let warning = item.warningMessage ?? "Requires attention"
            print(OutputFormatter.item(OutputFormatter.warn, "\(item.name) — \(OutputFormatter.formatSizeMB(item.sizeMB))"))
            print(OutputFormatter.item(OutputFormatter.dot, OutputFormatter.dim(warning)))
        }
    }

    print()
    print(OutputFormatter.safetyFootnote())

    // Phase 3: Call to Action
    print()
    print(OutputFormatter.section("✨ Action"))
    print(OutputFormatter.item(OutputFormatter.bold(OutputFormatter.cyan("[Enter]")), "Clean recommended items"))
    print(OutputFormatter.item(OutputFormatter.bold(OutputFormatter.cyan("[a]")), "Clean everything shown"))
    print(OutputFormatter.item(OutputFormatter.bold(OutputFormatter.cyan("[q]")), "Quit"))
    fflush(stdout)

    let input = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if input == "q" || input == "quit" {
        print(OutputFormatter.dim("Cancelled. Your workstation stays as-is."))
        return EXIT_SUCCESS
    }

    let itemsToClean: [CleanupPlan.CleanupItem]
    if input == "a" || input == "all" {
        itemsToClean = plan.items
        print()
        print(OutputFormatter.yellow("Cleaning everything shown..."))
    } else {
        itemsToClean = recommended
        if recommended.isEmpty {
            print()
            print(OutputFormatter.item(OutputFormatter.warn, OutputFormatter.yellow("No recommended items. Run with 'a' to clean review items.")))
            return EXIT_SUCCESS
        }
        print()
        print(OutputFormatter.green("Cleaning recommended items..."))
    }

    // Phase 4: Execute
    let cleanPlan = CleanupPlan(items: itemsToClean, totalSizeMB: itemsToClean.reduce(0) { $0 + $1.sizeMB })
    let result = CleanupEngine().apply(plan: cleanPlan, config: config)

    // Phase 5: Success Summary
    print()
    let cleanedCount = result.steps.filter { $0.success }.count
    print(OutputFormatter.panel(title: "✨ Cleanup Complete", lines: [
        "\(OutputFormatter.green("✓")) Freed: \(OutputFormatter.formatSizeMB(result.totalFreedMB))",
        "\(OutputFormatter.green("✓")) Cleaned: \(cleanedCount) items",
        "\(OutputFormatter.dim("◦")) Skipped: \(result.skipped.count) items",
    ]))

    // Show what was cleaned
    print()
    print(OutputFormatter.section("Cleaned"))
    for step in result.steps where step.success {
        print(OutputFormatter.item(OutputFormatter.check, "\(step.name) — \(OutputFormatter.formatSizeMB(step.freedMB))"))
    }

    // Show what was skipped
    if !result.skipped.isEmpty {
        print()
        print(OutputFormatter.section("Skipped"))
        for skipped in result.skipped {
            print(OutputFormatter.item(OutputFormatter.dot, "\(skipped.name) — \(OutputFormatter.dim(skipped.reason))"))
        }
    }

    print()
    print(OutputFormatter.actionFooter([
        "Run 'pulse' to clean again",
        "Run 'pulse artifacts' to check project junk",
        "Run 'pulse audit models' to check AI model storage",
    ]))

    return result.failureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE
}

// MARK: - Command Dispatch

private func runCommand(_ command: String, _ args: [String]) -> Int32 {
    switch command {
    case "analyze", "scan":
        return AnalyzeCommand.run(autoJsonArgs(args))
    case "artifacts":
        return ArtifactsCommand.run(autoJsonArgs(args))
    case "audit", "health":
        return AuditCommand.run(autoJsonArgs(args))
    case "models":
        return AuditCommand.run(autoJsonArgs(["models"] + args))
    case "clean", "cleanup":
        return CleanCommand.run(autoJsonArgs(args))
    case "completion":
        return CompletionCommand.run(args)
    case "doctor", "check":
        return DoctorCommand.run(autoJsonArgs(args))
    case "--help", "-h", "help":
        print(Usage.help())
        return EXIT_SUCCESS
    case "--version", "-v":
        print(BuildVersion.cliString())
        return EXIT_SUCCESS
    default:
        print(OutputFormatter.red("Error: Unknown command '\(command)'"))
        print()
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Try '\(OutputFormatter.bold("pulse --help"))' for command guide.")))
        print()
        print(Usage.help())
        return EXIT_FAILURE
    }
}

// MARK: - Entry Point

let arguments = CommandLine.arguments.dropFirst()

guard !arguments.isEmpty else {
    if isatty(fileno(stdout)) != 0 {
        exit(runUnified())
    } else {
        print(Usage.help())
    }
    exit(EXIT_SUCCESS)
}

let command = arguments.first!
exit(runCommand(command, Array(arguments.dropFirst())))
