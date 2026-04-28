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

    static func cyan(_ text: String) -> String {
        styleIfTTY(text, code: "36")
    }

    // MARK: - Icons

    static let check = green("✓")
    static let cross = red("✗")
    static let warn = yellow("⚠")
    static let info = cyan("ℹ")
    static let arrow = cyan("→")
    static let dot = dim("•")
    static let trash = "🗑"
    static let sparkles = "✨"

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
        output += String(repeating: "─", count: totalWidth) + "\n"

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

    // MARK: - Animated Spinner

    /// Simple animated spinner for long operations.
    /// Usage:
    ///   let spinner = OutputFormatter.Spinner(message: "Scanning...")
    ///   spinner.start()
    ///   // ... do work ...
    ///   spinner.stop(success: true)
    class Spinner {
        private let message: String
        private let frames = ["⠋", "", "⠹", "⠸", "⠼", "", "⠦", "⠧", "⠇", ""]
        private var timer: Timer?
        private var frameIndex = 0
        private var startTime: Date?

        init(message: String) {
            self.message = message
        }

        func start() {
            guard isTTY else { print("\(message)"); return }
            startTime = Date()
            timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in
                guard let self = self else { return }
                let frame = self.frames[self.frameIndex % self.frames.count]
                self.frameIndex += 1
                let elapsed = Date().timeIntervalSince(self.startTime ?? Date())
                let output = "\r\(frame) \(self.message) (\(String(format: "%.1f", elapsed))s)"
                fputs(output, stderr)
                fflush(stderr)
            }
            RunLoop.current.add(timer!, forMode: .common)
        }

        func stop(success: Bool = true) {
            timer?.invalidate()
            timer = nil
            guard isTTY else { return }
            let elapsed = Date().timeIntervalSince(startTime ?? Date())
            let icon = success ? OutputFormatter.check : OutputFormatter.cross
            let output = "\r\(icon) \(message) (\(String(format: "%.1f", elapsed))s)\n"
            fputs(output, stderr)
            fflush(stderr)
        }
    }

    // MARK: - Section Headers

    static func section(_ title: String) -> String {
        "\n\(bold(title))\n\(String(repeating: "─", count: title.count))"
    }

    static func item(_ icon: String, _ text: String) -> String {
        "  \(icon) \(text)"
    }

    static func command(_ command: String, description: String) -> String {
        let width = 30
        if command.count > width {
            return "  \(bold(command))\n  \(String(repeating: " ", count: width)) \(description)"
        }
        let padded = command.padding(toLength: width, withPad: " ", startingAt: 0)
        return "  \(bold(padded)) \(description)"
    }

    static func keyValue(_ key: String, _ value: String) -> String {
        "  \(bold(key)) \(value)"
    }

    static func safetyFootnote() -> String {
        item(info, dim("Pulse never deletes system paths, app bundles, or user documents."))
    }

    static func panel(title: String, lines: [String]) -> String {
        guard isTTY else {
            return ([section(title)] + lines).joined(separator: "\n")
        }

        let content = lines.isEmpty ? [""] : lines
        let width = max(title.count + 4, content.map { $0.count }.max() ?? 0)
        let innerWidth = max(width, 28)
        let topTitle = " \(title) "
        let topLine = cyan("╭") + bold(cyan(topTitle)) + cyan(String(repeating: "─", count: max(0, innerWidth - topTitle.count))) + cyan("╮")
        let body = content.map { line in
            let padded = line.padding(toLength: innerWidth, withPad: " ", startingAt: 0)
            return dim("│") + padded + dim("│")
        }
        let bottom = cyan("╰") + cyan(String(repeating: "─", count: innerWidth)) + cyan("╯")
        return ([topLine] + body + [bottom]).joined(separator: "\n")
    }

    static func actionFooter(_ items: [String]) -> String {
        items.map { item(arrow, dim($0)) }.joined(separator: "\n")
    }
}

// MARK: - Usage

enum Usage {
    static func landingScreen() -> String {
        // Modern "Hero" layout: Minimalist, Action-Oriented, Premium.
        // We use the 'create-agent-tui' skill principles:
        // 1. Clear hierarchy (Hero action is dominant).
        // 2. Safety assurance is present but not intrusive.
        // 3. Less visual noise (no nested boxes).

        return """
        \(OutputFormatter.bold(BuildVersion.cliString()))
        \(OutputFormatter.dim("AI Workstation Cleanup — Safe, Preview-First"))

        \(OutputFormatter.section("Action"))
        \(OutputFormatter.bold(OutputFormatter.green("  Clean your workstation")))
        \(OutputFormatter.dim("  Safely reclaim space from caches, logs, and old artifacts."))

        \(OutputFormatter.section("Advanced"))
        \(OutputFormatter.dim("  Analyze"))      \(OutputFormatter.dim("View reclaimable cache space"))
        \(OutputFormatter.dim("  Audit"))        \(OutputFormatter.dim("Check for stale machine issues"))
        \(OutputFormatter.dim("  Artifacts"))    \(OutputFormatter.dim("Find project build junk"))
        \(OutputFormatter.dim("  Doctor"))       \(OutputFormatter.dim("Health check & diagnostics"))

        \(OutputFormatter.section("Trust"))
        \(OutputFormatter.dim("  Preview-first · Protected paths · Stable JSON"))

        \(OutputFormatter.section("Input"))
        \(OutputFormatter.bold(OutputFormatter.cyan("  [Enter]")))  \(OutputFormatter.dim("Clean recommended items"))
        \(OutputFormatter.bold(OutputFormatter.cyan("  [a]")))      \(OutputFormatter.dim("Clean everything shown"))
        \(OutputFormatter.bold(OutputFormatter.cyan("  [q]")))      \(OutputFormatter.dim("Quit"))
        \(OutputFormatter.dim("  [?]"))            \(OutputFormatter.dim("Help"))
        """
    }

    static func help() -> String {
        """
        \(OutputFormatter.bold(BuildVersion.cliString()))
        \(OutputFormatter.dim("Safe cleanup and machine audit for macOS developers"))

        \(OutputFormatter.section("Start here"))
        \(OutputFormatter.command("pulse doctor", description: "Verify install, toolchain, and permissions"))
        \(OutputFormatter.command("pulse analyze", description: "See reclaimable cache space across profiles"))
        \(OutputFormatter.command("pulse clean", description: "Preview exactly what Pulse would remove"))

        \(OutputFormatter.section("Commands"))
        \(OutputFormatter.command("pulse analyze", description: "Scan Xcode, Homebrew, Node, Python, Bun, Rust, Claude, Cursor, and installers"))
        \(OutputFormatter.command("pulse scan", description: "Friendly alias for pulse analyze"))
        \(OutputFormatter.command("pulse artifacts", description: "Find build artifacts in project directories"))
        \(OutputFormatter.command("pulse audit", description: "Audit stale developer-machine issues"))
        \(OutputFormatter.command("pulse health", description: "Friendly alias for pulse audit"))
        \(OutputFormatter.command("pulse audit index-bloat", description: "Audit repos that slow AI IDE indexing"))
        \(OutputFormatter.command("pulse audit agent-data", description: "Audit Claude/Cursor data retention"))
        \(OutputFormatter.command("pulse audit models", description: "Audit Ollama / LM Studio model storage"))
        \(OutputFormatter.command("pulse clean", description: "Preview cleanup for all supported profiles"))
        \(OutputFormatter.command("pulse cleanup", description: "Friendly alias for pulse clean"))
        \(OutputFormatter.command("pulse clean --profile <name>", description: "Preview or apply one cleanup profile"))
        \(OutputFormatter.command("pulse doctor", description: "Check environment readiness and optional access"))
        \(OutputFormatter.command("pulse check", description: "Friendly alias for pulse doctor"))
        \(OutputFormatter.command("pulse completion <shell>", description: "Generate shell completion scripts"))

        \(OutputFormatter.section("Supported cleanup profiles"))
        \(OutputFormatter.command("xcode", description: "DerivedData, Archives, DeviceSupport, Simulators"))
        \(OutputFormatter.command("homebrew", description: "Download cache, old formulae, old casks"))
        \(OutputFormatter.command("node", description: "npm cache, Yarn cache, pnpm store"))
        \(OutputFormatter.command("python", description: "pip, Poetry, and uv caches"))
        \(OutputFormatter.command("bun", description: "Bun install cache"))
        \(OutputFormatter.command("rust", description: "Cargo registry and git caches"))
        \(OutputFormatter.command("claude", description: "Claude Code logs, caches, and transcripts"))
        \(OutputFormatter.command("cursor", description: "Cursor IDE caches, logs, and workspace storage"))
        \(OutputFormatter.command("installers", description: "Old installers and archives in Downloads/Desktop"))

        \(OutputFormatter.section("Common flags"))
        \(OutputFormatter.command("--dry-run", description: "Preview cleanup without deleting anything"))
        \(OutputFormatter.command("--apply", description: "Execute cleanup after confirmation"))
        \(OutputFormatter.command("--yes, -y", description: "Skip confirmation for automation / CI"))
        \(OutputFormatter.command("--json", description: "Machine-readable output for scripting"))
        \(OutputFormatter.command("--help, -h", description: "Show command help"))
        \(OutputFormatter.command("--version, -v", description: "Show current Pulse CLI version"))

        \(OutputFormatter.section("Examples"))
        \(OutputFormatter.command("pulse analyze", description: "Best first scan for reclaimable cache space"))
        \(OutputFormatter.command("pulse clean --profile claude", description: "Review Claude Code cleanup items"))
        \(OutputFormatter.command("pulse clean --profile cursor", description: "Review Cursor cleanup items"))
        \(OutputFormatter.command("pulse clean --profile bun", description: "Review Bun cache cleanup"))
        \(OutputFormatter.command("pulse clean --profile rust", description: "Review Rust/Cargo cache cleanup"))
        \(OutputFormatter.command("pulse clean --profile installers", description: "Review stale installer/archive cleanup"))
        \(OutputFormatter.command("pulse audit index-bloat", description: "Find repos slowing Cursor/VS Code"))
        \(OutputFormatter.command("pulse audit models", description: "Review Ollama / LM Studio model storage"))
        \(OutputFormatter.command("pulse artifacts --all", description: "Include recently modified project artifacts"))
        \(OutputFormatter.command("pulse clean --profile xcode", description: "Preview or apply one profile"))
        \(OutputFormatter.command("pulse doctor --json", description: "Use in scripts and setup checks"))
        \(OutputFormatter.command("pulse completion zsh > _pulse", description: "Install shell completion"))

        \(OutputFormatter.section("Safety"))
        \(OutputFormatter.item(OutputFormatter.check, "Preview-first by default"))
        \(OutputFormatter.item(OutputFormatter.check, "Protected paths blocked in code"))
        \(OutputFormatter.item(OutputFormatter.check, "Stable JSON output for automation"))
        """
    }
}
