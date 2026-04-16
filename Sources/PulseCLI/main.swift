//
//  main.swift
//  PulseCLI
//
//  Command-line interface for Pulse cleanup tool.
//

import Foundation

// MARK: - Entry Point

let arguments = CommandLine.arguments.dropFirst()

guard !arguments.isEmpty else {
    print(Usage.help())
    exit(EXIT_SUCCESS)
}

let command = arguments.first!

switch command {
case "analyze":
    exit(AnalyzeCommand.run(Array(arguments.dropFirst())))
case "clean":
    exit(CleanCommand.run(Array(arguments.dropFirst())))
case "--help", "-h", "help":
    print(Usage.help())
    exit(EXIT_SUCCESS)
case "--version", "-v":
    print("Pulse CLI 0.1.0-alpha")
    exit(EXIT_SUCCESS)
default:
    print("Error: Unknown command '\(command)'")
    print()
    print(Usage.help())
    exit(EXIT_FAILURE)
}
