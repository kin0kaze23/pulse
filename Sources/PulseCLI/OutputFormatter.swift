//
//  OutputFormatter.swift
//  PulseCLI
//
//  Terminal output formatting for Pulse CLI.
//

import Foundation
import PulseCore

/// Terminal output formatter for CLI commands.
enum OutputFormatter {

    // MARK: - Text Styling

    static func bold(_ text: String) -> String {
        "\u{001B}[1m\(text)\u{001B}[0m"
    }

    static func green(_ text: String) -> String {
        "\u{001B}[32m\(text)\u{001B}[0m"
    }

    static func yellow(_ text: String) -> String {
        "\u{001B}[33m\(text)\u{001B}[0m"
    }

    static func red(_ text: String) -> String {
        "\u{001B}[31m\(text)\u{001B}[0m"
    }

    static func dim(_ text: String) -> String {
        "\u{001B}[2m\(text)\u{001B}[0m"
    }

    // MARK: - Helpers

    static func formatSizeMB(_ mb: Double) -> String {
        if mb >= 1024 {
            return String(format: "%.1f GB", mb / 1024)
        }
        return String(format: "%.0f MB", mb)
    }

    static func formatPriority(_ priority: CleanupPriority) -> String {
        switch priority {
        case .high: return green("High")
        case .medium: return yellow("Medium")
        case .low: return dim("Low")
        case .optional: return dim("Optional")
        }
    }

    static func formatWarning(_ text: String) -> String {
        "\(yellow("  Warning:")) \(text)"
    }

    // MARK: - Table

    /// Render a table with aligned columns.
    static func table(headers: [String], rows: [[String]], padding: Int = 2) -> String {
        guard !rows.isEmpty else { return "" }

        let allRows = [headers] + rows
        let colWidths = (0..<headers.count).map { col in
            allRows.map { $0[col].count }.max() ?? 0
        }

        var output = ""

        // Header
        for (i, header) in headers.enumerated() {
            let width = colWidths[i]
            output += header.padding(toLength: width + padding, withPad: " ", startingAt: 0)
        }
        output += "\n"

        // Separator
        let totalWidth = colWidths.reduce(0) { $0 + $1 + padding }
        output += String(repeating: "-", count: totalWidth) + "\n"

        // Rows
        for row in rows {
            for (i, cell) in row.enumerated() {
                let width = colWidths[i]
                output += cell.padding(toLength: width + padding, withPad: " ", startingAt: 0)
            }
            output += "\n"
        }

        return output
    }
}

// MARK: - Usage

enum Usage {
    static func help() -> String {
        """
        \(OutputFormatter.bold("Pulse CLI")) v0.1.0-alpha

        Usage:
          pulse analyze                    Scan for cleanup candidates
          pulse clean --dry-run            Preview cleanup (all profiles)
          pulse clean --profile <name>     Preview cleanup for specific profile
          pulse clean --profile <name> --apply  Execute cleanup

        Supported profiles:
          xcode       Xcode caches (DerivedData, Archives, DeviceSupport, Simulators)
          homebrew    Homebrew caches (downloads, old formulae/casks)
          node        Node.js package manager caches (npm, yarn, pnpm)

        Options:
          --profile <name>  Target a specific cleanup profile
          --dry-run         Show what would be cleaned without deleting
          --apply           Execute the cleanup (requires confirmation)
          --help, -h        Show this help message
          --version, -v     Show version

        Examples:
          pulse analyze
          pulse clean --dry-run
          pulse clean --profile xcode --dry-run
          pulse clean --profile homebrew --apply
        """
    }
}
