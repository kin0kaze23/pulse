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

// MARK: - Entry Point

let arguments = CommandLine.arguments.dropFirst()

guard !arguments.isEmpty else {
    if isatty(fileno(stdout)) != 0 {
        print(Usage.landingScreen())
    } else {
        print(Usage.help())
    }
    exit(EXIT_SUCCESS)
}

let command = arguments.first!

switch command {
case "analyze":
    exit(AnalyzeCommand.run(autoJsonArgs(Array(arguments.dropFirst()))))
case "artifacts":
    exit(ArtifactsCommand.run(autoJsonArgs(Array(arguments.dropFirst()))))
case "audit":
    exit(AuditCommand.run(autoJsonArgs(Array(arguments.dropFirst()))))
case "clean":
    exit(CleanCommand.run(autoJsonArgs(Array(arguments.dropFirst()))))
case "completion":
    exit(CompletionCommand.run(Array(arguments.dropFirst())))
case "doctor":
    exit(DoctorCommand.run(autoJsonArgs(Array(arguments.dropFirst()))))
case "--help", "-h", "help":
    print(Usage.help())
    exit(EXIT_SUCCESS)
case "--version", "-v":
    print(BuildVersion.cliString())
    exit(EXIT_SUCCESS)
default:
    print(OutputFormatter.red("Error: Unknown command '\(command)'"))
    print()
    print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Try '\(OutputFormatter.bold("pulse --help"))' to see the full command guide.")))
    print()
    print(Usage.help())
    exit(EXIT_FAILURE)
}
