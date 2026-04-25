//
//  main.swift
//  PulseCLI
//
//  Command-line interface for Pulse cleanup tool.
//

import Foundation

// MARK: - Banner

/// Print a minimal branded header when pulse runs with no args.
/// Colors are only applied when stdout is a TTY (matching OutputFormatter behavior).
private func banner() -> String {
    let isTTY = isatty(fileno(stdout)) != 0
    let bold = { (t: String) -> String in isTTY ? "\u{001B}[1m\(t)\u{001B}[0m" : t }
    let dim = { (t: String) -> String in isTTY ? "\u{001B}[2m\(t)\u{001B}[0m" : t }
    let cyan = { (t: String) -> String in isTTY ? "\u{001B}[36m\(t)\u{001B}[0m" : t }
    let tag = BuildVersion.resolved()
    return """
    \(bold("Pulse")) \(cyan(tag))
    \(dim("Safe cleanup and machine audit for macOS developers"))
    """
}

// MARK: - Auto JSON Detection

/// When stdout is not a TTY (piped or redirected), auto-inject `--json`
/// so that `pulse doctor | jq .health_score` works without an explicit flag.
/// This matches the behavior of tools like Mole (`mo status` auto-detects piping).
private func autoJsonArgs(_ args: [String]) -> [String] {
    let isTTY = isatty(fileno(stdout)) != 0
    guard !isTTY, !args.contains("--json") else { return Array(args) }
    return Array(args) + ["--json"]
}

// MARK: - Command Dispatch

private func runCommand(_ command: String, _ args: [String]) -> Int32 {
    switch command {
    case "analyze":
        return AnalyzeCommand.run(autoJsonArgs(args))
    case "artifacts":
        return ArtifactsCommand.run(autoJsonArgs(args))
    case "audit":
        return AuditCommand.run(autoJsonArgs(args))
    case "clean":
        return CleanCommand.run(autoJsonArgs(args))
    case "completion":
        return CompletionCommand.run(args)
    case "doctor":
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
        print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Try '\(OutputFormatter.bold("pulse --help"))' to see the full command guide.")))
        print()
        print(Usage.help())
        return EXIT_FAILURE
    }
}

private func runLandingInteraction() -> Int32 {
    print(Usage.landingScreen())
    print()
    print(OutputFormatter.bold("Choice:"), terminator: " ")
    fflush(stdout)

    let input = TTYInput.readKey() ?? "q"
    switch input {
    case "1": return runCommand("doctor", [])
    case "2", "enter": return runCommand("analyze", [])
    case "3": return runCommand("clean", [])
    case "4": return runCommand("artifacts", [])
    case "5": return runCommand("audit", [])
    case "h", "help": return runCommand("help", [])
    default:
        print(OutputFormatter.dim("Exited Pulse."))
        return EXIT_SUCCESS
    }
}

// MARK: - Entry Point

let arguments = CommandLine.arguments.dropFirst()

guard !arguments.isEmpty else {
    if isatty(fileno(stdout)) != 0 {
        exit(runLandingInteraction())
    } else {
        print(Usage.help())
    }
    exit(EXIT_SUCCESS)
}

let command = arguments.first!
exit(runCommand(command, Array(arguments.dropFirst())))
