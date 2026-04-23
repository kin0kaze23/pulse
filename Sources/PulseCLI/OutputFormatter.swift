//
//  OutputFormatter.swift
//  PulseCLI
//
//  Terminal output formatting for Pulse CLI.
//

import Foundation
import PulseCore

// MARK: - TTY Detection

/// True when stdout is connected to a terminal (not piped or redirected).
private let isTTY = isatty(fileno(stdout)) != 0

/// Colorize a string with the given ANSI code, or return plain text if not a TTY.
private func styleIfTTY(_ text: String, code: String) -> String {
    isTTY ? "\u{001B}[\(code)m\(text)\u{001B}[0m" : text
}

/// Terminal output formatter for CLI commands.
enum OutputFormatter {

    // MARK: - Text Styling

    static func bold(_ text: String) -> String {
        styleIfTTY(text, code: "1")
    }

    static func green(_ text: String) -> String {
        styleIfTTY(text, code: "32")
    }

    static func yellow(_ text: String) -> String {
        styleIfTTY(text, code: "33")
    }

    static func red(_ text: String) -> String {
        styleIfTTY(text, code: "31")
    }

    static func dim(_ text: String) -> String {
        styleIfTTY(text, code: "2")
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

    // MARK: - JSON Action Labels

    /// Stable action label convention shared across all commands:
    ///   "delete" — file deletion
    ///   "command:<cmd>" — shell command to run
    /// Single source of truth to prevent drift between analyze and clean JSON.
    static func actionLabel(_ action: CleanupAction) -> String {
        switch action {
        case .file:
            return "delete"
        case .command(let cmd):
            return "command:\(cmd)"
        }
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
          pulse artifacts                  Scan for build artifacts
          pulse audit                      Scan dev environment issues
          pulse clean --dry-run            Preview cleanup (all profiles)
          pulse clean --profile <name>     Preview cleanup for specific profile
          pulse clean --profile <name> --apply  Execute cleanup
          pulse doctor                     Verify installation and environment
          pulse completion <shell>         Generate shell completion scripts

        Supported profiles:
          xcode       Xcode caches (DerivedData, Archives, DeviceSupport, Simulators)
          homebrew    Homebrew caches (downloads, old formulae/casks)
          node        Node.js package manager caches (npm, yarn, pnpm)

        Options:
          --profile <name>  Target a specific cleanup profile
          --dry-run         Show what would be cleaned without deleting
          --apply           Execute the cleanup (requires confirmation)
          --yes, -y         Skip confirmation prompt (for CI/CD automation)
          --json            Output as JSON (for scripting/automation)
          --help, -h        Show this help message
          --version, -v     Show version

        Examples:
          pulse analyze
          pulse analyze --json
          pulse artifacts
          pulse artifacts --apply --yes
          pulse audit
          pulse clean --dry-run
          pulse clean --profile xcode --dry-run --json
          pulse clean --profile homebrew --apply
          pulse doctor
          pulse completion zsh > /usr/local/share/zsh/site-functions/_pulse
        """
    }
}
