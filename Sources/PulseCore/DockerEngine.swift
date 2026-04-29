//
//  DockerEngine.swift
//  PulseCore
//
//  Scans for Docker usage and offers system prune.
//
//

import Foundation

public struct DockerEngine {

    public init() {}

    private struct Target {
        let name: String
        let path: String
        let minSizeMB: Double
        let warningMessage: String?

        static let all: [Target] = [
            .init(
                name: "Docker Containers & Images",
                path: "~/Library/Containers/com.docker.docker",
                minSizeMB: 500,
                warningMessage: "Runs 'docker system prune'. Removes stopped containers and unused images."
            ),
        ]
    }

    public func scan() -> CleanupPlan {
        // Check if docker CLI is available
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        task.arguments = ["which", "docker"]
        task.standardOutput = Pipe()
        task.standardError = Pipe()
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus != 0 {
                // Docker not found, return empty plan
                return CleanupPlan(items: [], totalSizeMB: 0)
            }
        } catch {
            return CleanupPlan(items: [], totalSizeMB: 0)
        }

        let scanner = DirectoryScanner()
        var items: [CleanupPlan.CleanupItem] = []

        for target in Target.all {
            let size = scanner.directorySizeMB(target.path)
            guard size >= target.minSizeMB else { continue }

            items.append(.init(
                name: target.name,
                sizeMB: size,
                category: .developer,
                path: target.path,
                isDestructive: true,
                requiresAppClosed: true,
                appName: "Docker Desktop",
                warningMessage: target.warningMessage,
                priority: .high,
                action: .command("docker system prune -f"),
                profile: .docker
            ))
        }

        return CleanupPlan(items: items, totalSizeMB: items.reduce(0) { $0 + $1.sizeMB })
    }
}
