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

private func runMenu() -> Int32 {
    // Clear screen for fresh start
    print("\u{001B}[2J\u{001B}[H", terminator: "")
    
    while true {
        // Clear screen before showing menu
        print("\u{001B}[2J\u{001B}[H", terminator: "")
        print(Usage.menuScreen())
        print()
        print(OutputFormatter.bold(OutputFormatter.cyan("Your choice:")), terminator: " ")
        fflush(stdout)

        let input = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // Clear the input line
        print("\u{001B}[A\u{001B}[2K\u{001B}[A\u{001B}[2K", terminator: "")
        
        switch input {
        case "1": 
            runCleanWorkstation()
            // Clear screen after returning
            print("\u{001B}[2J\u{001B}[H", terminator: "")
        case "2": 
            AnalyzeCommand.run([])
            print("\n\u{001B}[2J\u{001B}[H", terminator: "")
        case "3": 
            CleanCommand.run(["--profile", "browser"])
            print("\n\u{001B}[2J\u{001B}[H", terminator: "")
        case "4": 
            CleanCommand.run(["--profile", "docker"])
            print("\n\u{001B}[2J\u{001B}[H", terminator: "")
        case "5": 
            AuditCommand.run(["models"])
            print("\n\u{001B}[2J\u{001B}[H", terminator: "")
        case "6": 
            DoctorCommand.run([])
            print("\n\u{001B}[2J\u{001B}[H", terminator: "")
        case "q", "quit", "exit":
            print()
            print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.bold("Thanks for using Pulse! Happy coding! 🚀")))
            print()
            return EXIT_SUCCESS
        case "h", "help", "?":
            print("\u{001B}[2J\u{001B}[H", terminator: "")
            print(Usage.help())
            print("\nPress Enter to return to menu...", terminator: "")
            fflush(stdout)
            _ = readLine()
            print("\u{001B}[2J\u{001B}[H", terminator: "")
        case "":
            // Empty input, just continue
            continue
        default:
            print()
            print(OutputFormatter.item(OutputFormatter.warn, OutputFormatter.red("Unknown command '\(input)'. Please select 1-6 or 'q' to quit.")))
            print(OutputFormatter.dim("Press Enter to continue..."), terminator: " ")
            fflush(stdout)
            _ = readLine()
            print("\u{001B}[A\u{001B}[2K\u{001B}[A\u{001B}[2K", terminator: "")
        }
    }
}

private func runCleanWorkstation() -> Int32 {
    // Hero Header
    print()
    print(OutputFormatter.headerBanner())
    print()
    print(OutputFormatter.section("🚀 Full Workstation Cleanup"))
    print(OutputFormatter.item(OutputFormatter.target, "Scanning all profiles for maximum space recovery..."))
    print()

    // Phase 1: Scan with premium spinner
    let spinner = OutputFormatter.Spinner(message: "Analyzing your system")
    spinner.start()

    let allProfiles: Set<CleanupProfile> = [.xcode, .homebrew, .node, .python, .bun, .rust, .claude, .cursor, .installers, .browser, .docker]
    let config = CleanupConfig(profiles: allProfiles)
    let plan = CleanupEngine().scan(config: config)

    spinner.stop(success: true)
    print()

    if plan.items.isEmpty {
        print()
        print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.bold(OutputFormatter.green("Perfect! Your AI workstation is already clean! 🎉"))))
        print()
        print(OutputFormatter.actionFooter([
            "Run 'pulse artifacts' to check project build junk",
            "Press Enter to return to menu",
        ]))
        _ = readLine()
        return EXIT_SUCCESS
    }

    // Phase 2: Show summary dashboard
    let recommended = plan.items.filter { item in
        item.warningMessage == nil && !item.requiresAppClosed && item.priority != .low && item.skipReason == nil
    }
    let review = plan.items.filter { item in !recommended.contains { $0.name == item.name && $0.path == item.path } }
    
    let recommendedSize = OutputFormatter.formatSizeMB(recommended.reduce(0) { $0 + $1.sizeMB })
    let reviewSize = OutputFormatter.formatSizeMB(review.reduce(0) { $0 + $1.sizeMB })
    let totalSize = OutputFormatter.formatSizeMB(plan.totalSizeMB)

    print()
    print(OutputFormatter.panel(title: "📊 Cleanup Analysis", lines: [
        "\(OutputFormatter.green("✓")) Safe to clean:  \(OutputFormatter.bold(recommendedSize))  (\(recommended.count) items)",
        "\(OutputFormatter.yellow("⚠")) Needs review:   \(OutputFormatter.bold(reviewSize))  (\(review.count) items)",
        "",
        "\(OutputFormatter.cyan("★")) Total recovery:  \(OutputFormatter.bold(OutputFormatter.green(totalSize)))",
    ]))

    // Show recommended items
    if !recommended.isEmpty {
        print()
        print(OutputFormatter.section("✅ Recommended (Safe to Clean)"))
        print(OutputFormatter.item(OutputFormatter.info, OutputFormatter.dim("These items can be safely removed without affecting your work")))
        print()
        for item in recommended {
            print(OutputFormatter.item(OutputFormatter.check, "\(item.name)"))
            print(OutputFormatter.item(OutputFormatter.dot, OutputFormatter.dim("   \(OutputFormatter.formatSizeMB(item.sizeMB)) • \(item.profile.rawValue)")))
        }
    }

    // Show review items
    if !review.isEmpty {
        print()
        print(OutputFormatter.section("⚠️  Needs Your Review"))
        print(OutputFormatter.item(OutputFormatter.info, OutputFormatter.dim("Please review these items before cleaning")))
        print()
        for item in review {
            let warning = item.warningMessage ?? "Requires attention"
            print(OutputFormatter.item(OutputFormatter.warn, "\(item.name)"))
            print(OutputFormatter.item(OutputFormatter.dot, OutputFormatter.dim("   \(OutputFormatter.formatSizeMB(item.sizeMB)) • \(warning)")))
        }
    }

    print()
    print(OutputFormatter.divider())
    print()
    print(OutputFormatter.section("🎯 What would you like to do?"))
    print()
    print(OutputFormatter.item(OutputFormatter.cyan("[Enter]"), OutputFormatter.bold("Clean safe items only") + " " + OutputFormatter.dim("(\(recommended.count) items, \(recommendedSize))")))
    print(OutputFormatter.item(OutputFormatter.cyan("[a]"), OutputFormatter.bold("Clean everything") + " " + OutputFormatter.dim("(\(plan.items.count) items, \(totalSize))")))
    print(OutputFormatter.item(OutputFormatter.cyan("[r]"), OutputFormatter.bold("Review items only") + " " + OutputFormatter.dim("(\(review.count) items, \(reviewSize))")))
    print(OutputFormatter.item(OutputFormatter.cyan("[q]"), "Return to menu"))
    print()
    fflush(stdout)

    let input = (readLine() ?? "").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

    if input == "q" || input == "quit" {
        print(OutputFormatter.dim("Returning to menu..."))
        return EXIT_SUCCESS
    }

    let itemsToClean: [CleanupPlan.CleanupItem]
    let actionName: String
    
    switch input {
    case "a", "all":
        itemsToClean = plan.items
        actionName = "all items"
        print()
        print(OutputFormatter.yellow("Cleaning all items..."))
    case "r", "review":
        itemsToClean = review
        actionName = "review items"
        if review.isEmpty {
            print()
            print(OutputFormatter.item(OutputFormatter.warn, OutputFormatter.yellow("No review items selected.")))
            return EXIT_SUCCESS
        }
        print()
        print(OutputFormatter.yellow("Cleaning review items..."))
    default:
        itemsToClean = recommended
        actionName = "safe items"
        if recommended.isEmpty {
            print()
            print(OutputFormatter.item(OutputFormatter.warn, OutputFormatter.yellow("No recommended items available.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Try selecting 'a' to clean all items or 'r' to review items.")))
            return EXIT_SUCCESS
        }
        print()
        print(OutputFormatter.green("Cleaning recommended items..."))
    }

    // Phase 3: Execute with progress
    print()
    let execSpinner = OutputFormatter.Spinner(message: "Cleaning \(actionName)")
    execSpinner.start()

    let cleanPlan = CleanupPlan(items: itemsToClean, totalSizeMB: itemsToClean.reduce(0) { $0 + $1.sizeMB })
    let result = CleanupEngine().apply(plan: cleanPlan, config: config)

    execSpinner.stop(success: true)
    print()

    // Phase 4: Success Summary
    let freedSize = OutputFormatter.formatSizeMB(result.totalFreedMB)
    print()
    print(OutputFormatter.panel(title: "🎉 Cleanup Complete!", lines: [
        "\(OutputFormatter.green("✓")) Space freed:    \(OutputFormatter.bold(OutputFormatter.green(freedSize)))",
        "\(OutputFormatter.green("✓")) Items cleaned:  \(OutputFormatter.bold("\(result.steps.filter { $0.success }.count)"))",
        "\(OutputFormatter.dim("◦")) Items skipped:  \(OutputFormatter.bold("\(result.skipped.count)"))",
    ]))

    // Show what was cleaned
    if result.steps.contains(where: { $0.success }) {
        print()
        print(OutputFormatter.section("Cleaned Items"))
        for step in result.steps where step.success {
            print(OutputFormatter.item(OutputFormatter.check, "\(step.name)"))
            print(OutputFormatter.item(OutputFormatter.dot, OutputFormatter.dim("   Freed \(OutputFormatter.formatSizeMB(step.freedMB))")))
        }
    }

    // Show what was skipped
    if !result.skipped.isEmpty {
        print()
        print(OutputFormatter.section("Skipped Items"))
        for skipped in result.skipped {
            print(OutputFormatter.item(OutputFormatter.dot, "\(skipped.name)"))
            print(OutputFormatter.item(OutputFormatter.dot, OutputFormatter.dim("   \(skipped.reason)")))
        }
    }

    print()
    print(OutputFormatter.divider())
    print()
    print(OutputFormatter.item(OutputFormatter.sparkles, OutputFormatter.bold("Great job! You've reclaimed \(OutputFormatter.green(freedSize)) of space! 🚀")))
    print()
    print(OutputFormatter.actionFooter([
        "Press Enter to return to menu",
        "Run 'pulse artifacts' to check project build junk",
        "Run 'pulse audit models' to check AI model storage",
    ]))
    _ = readLine()

    return result.failureCount == 0 ? EXIT_SUCCESS : EXIT_FAILURE
}

private func runUnified() -> Int32 {
    return runMenu()
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
