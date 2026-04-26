//
//  AIWorkstationAudits.swift
//  PulseCore
//
//  AI-workstation-specific audits for index bloat and agent-data retention.
//  Pure Swift, no AppKit, no SwiftUI.
//

import Foundation

public struct IndexBloatAuditScanner {
    private let fileManager: FileManager
    private let scanner: DirectoryScanner

    public init(fileManager: FileManager = .default, scanner: DirectoryScanner = DirectoryScanner()) {
        self.fileManager = fileManager
        self.scanner = scanner
    }

    public func scan(config: PulseConfig = .load()) -> [AuditIssue] {
        let offenderNames = ["node_modules", ".next", ".nuxt", "dist", "build", "coverage", ".build", "target", ".venv", "venv", "__pycache__"]
        var issues: [AuditIssue] = []

        for root in config.effectiveArtifactScanPaths {
            let expandedRoot = NSString(string: root).expandingTildeInPath
            guard let children = try? fileManager.contentsOfDirectory(atPath: expandedRoot) else { continue }

            for child in children {
                let projectPath = (expandedRoot as NSString).appendingPathComponent(child)
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: projectPath, isDirectory: &isDir), isDir.boolValue else { continue }
                guard looksLikeProject(projectPath) else { continue }

                let offenders = offenderNames.compactMap { name -> (String, Double)? in
                    let offenderPath = (projectPath as NSString).appendingPathComponent(name)
                    let size = scanner.directorySizeMB(offenderPath)
                    return size >= 50 ? (name, size) : nil
                }

                let total = offenders.reduce(0) { $0 + $1.1 }
                guard total >= 250 else { continue }

                let hasCursorIgnore = fileManager.fileExists(atPath: (projectPath as NSString).appendingPathComponent(".cursorignore"))
                let top = offenders.sorted { $0.1 > $1.1 }.prefix(3)
                let offenderText = top.map { "\($0.0) (\(formatSize($0.1)))" }.joined(separator: ", ")
                let patterns = suggestedIgnorePatterns(for: offenders.map { $0.0 })
                let suggestionHeader = hasCursorIgnore
                    ? "Suggested .cursorignore additions:"
                    : "Suggested .cursorignore:"
                let suggestion = ([
                    hasCursorIgnore
                        ? "Review .cursorignore and watcher/search excludes for generated folders."
                        : "Add a .cursorignore to keep generated folders out of Cursor/VS Code indexing.",
                    suggestionHeader,
                ] + patterns.map { "  \($0)" }).joined(separator: "\n")

                issues.append(AuditIssue(
                    title: "Index bloat risk in \(child)",
                    description: "Large generated folders can slow Cursor/VS Code indexing. Top offenders: \(offenderText). \(suggestion)",
                    reclaimableMB: total,
                    severity: total > 2048 ? .warning : .info,
                    category: .aiWorkspace,
                    path: projectPath
                ))
            }
        }

        return issues.sorted { ($0.reclaimableMB ?? 0) > ($1.reclaimableMB ?? 0) }
    }

    private func looksLikeProject(_ path: String) -> Bool {
        let markers = [".git", "package.json", "pyproject.toml", "Cargo.toml", "go.mod", ".cursor"]
        return markers.contains { fileManager.fileExists(atPath: (path as NSString).appendingPathComponent($0)) }
    }

    private func formatSize(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }

    private func suggestedIgnorePatterns(for names: [String]) -> [String] {
        let order = ["node_modules", ".next", ".nuxt", "dist", "build", "coverage", ".build", "target", ".venv", "venv", "__pycache__"]
        let set = Set(names)
        return order.filter { set.contains($0) }
    }
}

public struct AgentDataAuditScanner {
    private let scanner: DirectoryScanner

    public init(scanner: DirectoryScanner = DirectoryScanner()) {
        self.scanner = scanner
    }

    public func scan() -> [AuditIssue] {
        let targets: [(String, String, Double, String)] = [
            ("Claude transcripts and tool results", "~/.claude/projects", 250, "Contains plaintext transcripts and tool output; review retention."),
            ("Claude debug logs", "~/.claude/debug", 50, "Old debug logs can grow unbounded on heavy agent workflows."),
            ("Claude CLI cache", "~/Library/Caches/claude-cli-nodejs", 50, "Safe to remove runtime cache data."),
            ("Cursor workspace storage", "~/Library/Application Support/Cursor/User/workspaceStorage", 250, "Contains workspace state, backups, and chat/editor history."),
            ("Cursor logs", "~/Library/Application Support/Cursor/logs", 25, "Safe to remove old logs after closing Cursor."),
        ]

        var issues: [AuditIssue] = []
        for (title, path, minSize, description) in targets {
            let size = scanner.directorySizeMB(path)
            guard size >= minSize else { continue }
            issues.append(AuditIssue(
                title: title,
                description: description,
                reclaimableMB: size,
                severity: size > 2048 ? .warning : .info,
                category: .aiWorkspace,
                path: path
            ))
        }
        return issues.sorted { ($0.reclaimableMB ?? 0) > ($1.reclaimableMB ?? 0) }
    }
}

public struct ModelsAuditScanner {
    private let scanner: DirectoryScanner
    private let fileManager: FileManager

    public init(scanner: DirectoryScanner = DirectoryScanner(), fileManager: FileManager = .default) {
        self.scanner = scanner
        self.fileManager = fileManager
    }

    public func scan() -> [AuditIssue] {
        var issues: [AuditIssue] = []

        let ollamaRoot = NSString(string: "~/.ollama").expandingTildeInPath
        let ollamaModels = (ollamaRoot as NSString).appendingPathComponent("models")
        let ollamaSize = scanner.directorySizeMB(ollamaModels)
        if ollamaSize >= 1024 {
            let logsSize = scanner.directorySizeMB((ollamaRoot as NSString).appendingPathComponent("logs"))
            let description = logsSize > 25
                ? "Large Ollama model storage detected. Review unused models and consider moving models with OLLAMA_MODELS. Logs are also present in ~/.ollama/logs."
                : "Large Ollama model storage detected. Review unused models and consider moving models with OLLAMA_MODELS."
            issues.append(AuditIssue(
                title: "Ollama models using \(formatSize(ollamaSize))",
                description: description,
                reclaimableMB: ollamaSize,
                severity: ollamaSize >= 10 * 1024 ? .warning : .info,
                category: .aiWorkspace,
                path: ollamaModels
            ))
        }

        let lmStudioPaths = [
            NSString(string: "~/.lmstudio/models").expandingTildeInPath,
            NSString(string: "~/.cache/lm-studio/models").expandingTildeInPath,
        ]

        for path in lmStudioPaths where fileManager.fileExists(atPath: path) {
            let size = scanner.directorySizeMB(path)
            guard size >= 1024 else { continue }
            issues.append(AuditIssue(
                title: "LM Studio models using \(formatSize(size))",
                description: "Review stale or duplicate local model files before deleting. If you mirror Ollama models into LM Studio, watch for duplicate storage.",
                reclaimableMB: size,
                severity: size >= 10 * 1024 ? .warning : .info,
                category: .aiWorkspace,
                path: path
            ))
        }

        if ollamaSize >= 1024 {
            for path in lmStudioPaths where fileManager.fileExists(atPath: path) {
                let lmSize = scanner.directorySizeMB(path)
                guard lmSize >= 1024 else { continue }
                issues.append(AuditIssue(
                    title: "Potential duplicate model storage across Ollama and LM Studio",
                    description: "Both Ollama and LM Studio model directories are large. Review whether the same models or quantizations are stored twice. Prefer a single source of truth or symlink strategy where appropriate.",
                    reclaimableMB: nil,
                    severity: .info,
                    category: .aiWorkspace,
                    path: nil
                ))
                break
            }
        }

        return issues.sorted { ($0.reclaimableMB ?? 0) > ($1.reclaimableMB ?? 0) }
    }

    private func formatSize(_ mb: Double) -> String {
        if mb >= 1024 { return String(format: "%.1f GB", mb / 1024) }
        return String(format: "%.0f MB", mb)
    }
}
