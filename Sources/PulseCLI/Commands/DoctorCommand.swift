//
//  DoctorCommand.swift
//  PulseCLI
//
//  "pulse doctor" — verify Pulse installation and environment.
//

import Foundation

enum DoctorCommand {

    static func run(_ args: [String]) -> Int32 {
        if args.contains("--help") || args.contains("-h") {
            print(BuildVersion.cliString())
            print()
            print("Usage: pulse doctor")
            print()
            print("Verify Pulse installation, toolchain status, and environment readiness.")
            print("Checks Swift, Xcode, Homebrew, package managers, permissions, and disk space.")
            print()
            print("Options:")
            print(OutputFormatter.command("--json", description: "Output as JSON"))
            return EXIT_SUCCESS
        }

        let jsonOutput = args.contains("--json")
        let checks = runAllChecks()

        if jsonOutput {
            return outputJSON(checks)
        }

        return outputHuman(checks)
    }

    // MARK: - Check Definitions

    struct Check: Encodable {
        let name: String
        let status: Status
        let detail: String
        let recommendation: String?

        enum Status: String, Encodable {
            case pass = "PASS"
            case warn = "WARN"
            case fail = "FAIL"
            case info = "INFO"
        }
    }

    // MARK: - Run All Checks

    private static func runAllChecks() -> [Check] {
        var checks: [Check] = []

        // 1. Swift toolchain
        checks.append(checkSwiftToolchain())

        // 2. Xcode installed
        checks.append(checkXcode())

        // 3. Homebrew installed
        checks.append(checkHomebrew())

        // 4. Node package managers
        checks.append(checkPackageManager("npm", profile: "node"))
        checks.append(checkPackageManager("yarn", profile: "node"))
        checks.append(checkPackageManager("pnpm", profile: "node"))

        // 5. Full Disk Access
        checks.append(checkFullDiskAccess())

        // 6. Disk space
        checks.append(checkDiskSpace())

        // 7. Pulse binary location
        checks.append(checkPulseLocation())

        return checks
    }

    // MARK: - Individual Checks

    private static func checkSwiftToolchain() -> Check {
        let version = runCommand("/usr/bin/swift", args: ["--version"])
        if let output = version, output.contains("Swift version") {
            let shortVersion = output.components(separatedBy: "\n").first ?? output
            return Check(
                name: "Swift toolchain",
                status: .pass,
                detail: shortVersion,
                recommendation: nil
            )
        }
        return Check(
            name: "Swift toolchain",
            status: .fail,
            detail: "Swift not found in PATH",
            recommendation: "Install Xcode command line tools: xcode-select --install"
        )
    }

    private static func checkXcode() -> Check {
        let path = runCommand("/usr/bin/xcode-select", args: ["-p"])
        if let xcodePath = path, !xcodePath.isEmpty, FileManager.default.fileExists(atPath: xcodePath.trimmingCharacters(in: .whitespacesAndNewlines)) {
            return Check(
                name: "Xcode",
                status: .pass,
                detail: xcodePath.trimmingCharacters(in: .whitespacesAndNewlines),
                recommendation: nil
            )
        }
        return Check(
            name: "Xcode",
            status: .warn,
            detail: "Xcode command line tools not found",
            recommendation: "Install with: xcode-select --install"
        )
    }

    private static func checkHomebrew() -> Check {
        let brewPath = findExecutable("brew")
        if let path = brewPath {
            let version = runCommand(path, args: ["--version"])
            let versionLine = version?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
            return Check(
                name: "Homebrew",
                status: .pass,
                detail: "\(path) (\(versionLine))",
                recommendation: nil
            )
        }
        return Check(
            name: "Homebrew",
            status: .warn,
            detail: "brew not found in PATH",
            recommendation: "Install from https://brew.sh (optional, needed for homebrew profile)"
        )
    }

    private static func checkPackageManager(_ name: String, profile: String) -> Check {
        let exePath = findExecutable(name)
        if let path = exePath {
            let version = runCommand(path, args: ["--version"])
            let versionLine = version?.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
            return Check(
                name: name,
                status: .pass,
                detail: "\(path) (\(versionLine))",
                recommendation: nil
            )
        }
        return Check(
            name: name,
            status: .info,
            detail: "\(name) not found in PATH",
            recommendation: nil  // Optional, not all users need all package managers
        )
    }

    private static func checkFullDiskAccess() -> Check {
        // Check if Pulse can access a directory that requires FDA
        let protectedTestPath = "/Library/Logs/DiagnosticReports"
        let canRead = FileManager.default.isReadableFile(atPath: protectedTestPath)
        if canRead {
            return Check(
                name: "Full Disk Access",
                status: .pass,
                detail: "Pulse has Full Disk Access",
                recommendation: nil
            )
        }
        return Check(
            name: "Full Disk Access",
            status: .warn,
            detail: "Full Disk Access not granted",
            recommendation: "Enable in System Settings → Privacy & Security → Full Disk Access (optional, enables deeper scans)"
        )
    }

    private static func checkDiskSpace() -> Check {
        let homeURL = FileManager.default.homeDirectoryForCurrentUser
        do {
            let values = try homeURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let bytes = values.volumeAvailableCapacityForImportantUsage {
                let gb = Double(bytes) / (1024.0 * 1024.0 * 1024.0)
                if gb < 10 {
                    return Check(
                        name: "Disk space",
                        status: .warn,
                        detail: String(format: "%.1f GB available", gb),
                        recommendation: "Low disk space may affect system performance. Run 'pulse clean --dry-run' to see reclaimable space."
                    )
                }
                return Check(
                    name: "Disk space",
                    status: .pass,
                    detail: String(format: "%.1f GB available", gb),
                    recommendation: nil
                )
            }
        } catch {
            // Fall back to simpler check
        }
        return Check(
            name: "Disk space",
            status: .info,
            detail: "Could not determine available disk space",
            recommendation: nil
        )
    }

    private static func checkPulseLocation() -> Check {
        // First check own process path
        let ownPath = CommandLine.arguments.first ?? ""
        if !ownPath.isEmpty && FileManager.default.isExecutableFile(atPath: ownPath) {
            return Check(
                name: "Pulse location",
                status: .pass,
                detail: ownPath,
                recommendation: nil
            )
        }

        // Then check PATH
        let pulsePath = findExecutable("pulse")
        if let path = pulsePath {
            return Check(
                name: "Pulse location",
                status: .pass,
                detail: path,
                recommendation: nil
            )
        }
        return Check(
            name: "Pulse location",
            status: .warn,
            detail: "pulse not found in PATH",
            recommendation: "Ensure .build/debug/pulse or .build/release/pulse is in your PATH"
        )
    }

    // MARK: - Helpers

    private static func findExecutable(_ name: String) -> String? {
        guard let pathEnv = ProcessInfo.processInfo.environment["PATH"] else { return nil }
        for dir in pathEnv.components(separatedBy: ":") {
            let fullPath = dir + "/" + name
            if FileManager.default.isExecutableFile(atPath: fullPath) {
                return fullPath
            }
        }
        return nil
    }

    private static func runCommand(_ executable: String, args: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = args

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)
        } catch {
            return nil
        }
    }

    // MARK: - Human Output

    /// Exit codes:
    ///   0 — All checks PASS (healthy)
    ///   1 — Any check FAIL (needs attention)
    ///   2 — No failures, but warnings present (works with limitations)
    private static func outputHuman(_ checks: [Check]) -> Int32 {
        print(OutputFormatter.bold("Pulse"))
        print(OutputFormatter.section("Pulse Doctor"))

        var hasWarnings = false
        var hasFailures = false
        var passCount = 0

        for check in checks {
            let statusText: String
            switch check.status {
            case .pass:
                statusText = OutputFormatter.green("[PASS]")
                passCount += 1
            case .warn:
                statusText = OutputFormatter.yellow("[WARN]")
                hasWarnings = true
            case .fail:
                statusText = OutputFormatter.red("[FAIL]")
                hasFailures = true
            case .info:
                statusText = OutputFormatter.dim("[INFO]")
            }

            print("  \(statusText) \(check.name)")
            print("       \(OutputFormatter.dim(check.detail))")

            if let rec = check.recommendation {
                print("       \(OutputFormatter.yellow("→")) \(OutputFormatter.dim(rec))")
            }
            print()
        }

        print(OutputFormatter.keyValue("Checks passed:", "\(passCount)/\(checks.count)"))
        print()

        if hasFailures {
            print(OutputFormatter.item(OutputFormatter.cross, OutputFormatter.red("Pulse needs attention before wider use.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Fix the FAIL items above, then run '\(OutputFormatter.bold("pulse doctor"))' again.")))
            return 1
        } else if hasWarnings {
            print(OutputFormatter.item(OutputFormatter.warn, OutputFormatter.yellow("Pulse works, but some optional features are limited.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("You can still use Pulse safely; address warnings when convenient.")))
            return 2
        } else {
            print(OutputFormatter.item(OutputFormatter.check, OutputFormatter.green("Pulse looks good and is ready to use.")))
            print(OutputFormatter.item(OutputFormatter.arrow, OutputFormatter.dim("Next: run '\(OutputFormatter.bold("pulse analyze"))' to see reclaimable space.")))
            return 0
        }
    }

    // MARK: - JSON Output

    /// JSON mode always exits 0 — status is encoded in the payload.
    /// Scripts should inspect `checks[].status` and `hasFailures`/`hasWarnings`
    /// fields to determine health, not the process exit code.
    private static func outputJSON(_ checks: [Check]) -> Int32 {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        let hasFailures = checks.contains { $0.status == .fail }
        let hasWarnings = checks.contains { $0.status == .warn }

        let output = DoctorJSON(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            checks: checks,
            hasFailures: hasFailures,
            hasWarnings: hasWarnings
        )

        do {
            let data = try encoder.encode(output)
            print(String(data: data, encoding: .utf8)!)
        } catch {
            let err = DoctorJSONError(error: error.localizedDescription)
            let data = try! encoder.encode(err)
            print(String(data: data, encoding: .utf8)!)
        }

        // Always exit 0 in JSON mode — scripts read status from the payload.
        return EXIT_SUCCESS
    }
}

// MARK: - JSON Schema

/// Stable JSON output schema for `pulse doctor --json`.
/// schemaVersion follows semver: major changes on incompatible schema updates.
/// Current: 1.0.0 — initial release.
struct DoctorJSON: Encodable {
    /// Schema version, not CLI version. Bumped on incompatible changes.
    let schemaVersion: String = "1.0.0"
    let command: String = "doctor"
    let timestamp: String
    let checks: [DoctorCommand.Check]
    /// True if any check returned FAIL. Scripts should use this instead of exit code.
    let hasFailures: Bool
    /// True if any check returned WARN (no failures). Scripts should use this instead of exit code.
    let hasWarnings: Bool
}

struct DoctorJSONError: Encodable {
    let schemaVersion: String = "1.0.0"
    let command: String = "doctor"
    let error: String
    let code: String = "ENCODE_FAILED"
}
