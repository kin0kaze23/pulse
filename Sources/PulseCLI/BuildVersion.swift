//
//  BuildVersion.swift
//  PulseCLI
//
//  Embedded version metadata for release binaries.
//  During CI release builds, this file is overwritten with the tag being built.
//

import Foundation

enum BuildVersion {
    /// Resolve CLI version from git tag in a git checkout.
    /// For release binaries built in CI (where `.git` metadata is not available at runtime),
    /// fall back to the embedded build version generated during the release workflow.
    static func resolved() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        task.arguments = ["describe", "--tags", "--abbrev=0"]
        task.standardOutput = Pipe()
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0,
               let data = (task.standardOutput as? Pipe)?.fileHandleForReading.readDataToEndOfFile(),
               let tag = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !tag.isEmpty {
                return tag
            }
        } catch {}

        if EmbeddedBuildVersion.value != "dev" { return EmbeddedBuildVersion.value }
        return "dev"
    }

    static func cliString() -> String {
        "Pulse CLI \(resolved())"
    }
}
