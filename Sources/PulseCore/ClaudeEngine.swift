//
//  ClaudeEngine.swift
//  PulseCore
//
//  Scans for Claude Code caches, logs, and session artifacts.
//  Pure Swift, no AppKit, no SwiftUI, no ObservableObject, no @Published.
//

import Foundation

public struct ClaudeEngine {

    public init() {}

    private struct Target {
        let name: String
        let path: String
        let minSizeMB: Double
        let priority: CleanupPriority
        let warningMessage: String?

        static let all: [Target] = [
            .init(
                name: "Claude debug logs",
                path: "~/.claude/debug",
                minSizeMB: 25,
                priority: .high,
                warningMessage: "Safe to remove old debug logs — Claude will recreate logs when needed"
            ),
            .init(
                name: "Claude paste cache",
                path: "~/.claude/paste-cache",
                minSizeMB: 25,
                priority: .high,
                warningMessage: "Safe to remove cached pasted content — this may contain plaintext snippets"
            ),
            .init(
                name: "Claude image cache",
                path: "~/.claude/image-cache",
                minSizeMB: 25,
                priority: .high,
                warningMessage: "Safe to remove cached image attachments"
            ),
            .init(
                name: "Claude shell snapshots",
                path: "~/.claude/shell-snapshots",
                minSizeMB: 10,
                priority: .medium,
                warningMessage: "Safe to remove stale shell snapshots after crashed sessions"
            ),
            .init(
                name: "Claude CLI cache",
                path: "~/Library/Caches/claude-cli-nodejs",
                minSizeMB: 50,
                priority: .high,
                warningMessage: "Safe to remove cached Claude CLI runtime data"
            ),
            .init(
                name: "Claude project transcripts",
                path: "~/.claude/projects",
                minSizeMB: 250,
                priority: .low,
                warningMessage: "Contains plaintext transcripts and tool outputs — review before removing"
            ),
        ]
    }

    public func scan() -> CleanupPlan {
        let scanner = DirectoryScanner()
        var items: [CleanupPlan.CleanupItem] = []

        for target in Target.all {
            let size = scanner.directorySizeMB(target.path)
            guard size >= target.minSizeMB else { continue }

            items.append(.init(
                name: target.name,
                sizeMB: size,
                category: .logs,
                path: target.path,
                isDestructive: false,
                requiresAppClosed: false,
                appName: nil,
                warningMessage: target.warningMessage,
                priority: target.priority,
                action: .file,
                profile: .claude
            ))
        }

        return CleanupPlan(items: items, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }
}
