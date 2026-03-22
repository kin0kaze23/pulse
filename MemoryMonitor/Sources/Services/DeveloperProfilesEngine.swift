import Foundation
import AppKit
import Combine

class DeveloperProfilesEngine: ObservableObject {
    static let shared = DeveloperProfilesEngine()

    @Published var profileStates: [ProfileState] = []
    @Published var customRules: [CustomRule] = []
    @Published var isRefreshing = false

    struct ProfileState: Identifiable {
        let id: String
        let profile: DeveloperProfile
        var isDetected: Bool       // Tool is installed
        var isRunning: Bool        // Process is currently running
        var memoryMB: Double       // Total RSS of matching processes
        var diskSizes: [String: Double]  // DiskScan.label → MB
        var totalDiskMB: Double
        var lastUpdated: Date
    }

    struct CustomRule: Identifiable, Codable {
        let id: UUID
        var name: String
        var icon: String           // SF Symbol name
        var cleanupCommand: String
        var description: String

        init(name: String, icon: String, cleanupCommand: String, description: String) {
            self.id = UUID()
            self.name = name
            self.icon = icon
            self.cleanupCommand = cleanupCommand
            self.description = description
        }
    }

    private let workQueue = DispatchQueue(label: "com.pulse.devprofiles", qos: .utility)

    private init() {
        loadCustomRules()
        // Initial refresh
        refresh()
    }

    func refresh() {
        guard !isRefreshing else { return }
        DispatchQueue.main.async { self.isRefreshing = true }

        workQueue.async { [weak self] in
            guard let self else { return }
            let psOutput = self.runPS()
            var states: [ProfileState] = []

            for profile in BuiltinProfiles.all {
                let isDetected = self.detect(profile.detectMethod)
                guard isDetected else { continue }  // Only show installed tools

                let isRunning = self.isRunning(profile, psOutput: psOutput)
                let memoryMB = self.measureMemory(profile, psOutput: psOutput)
                var diskSizes: [String: Double] = [:]
                var totalDisk: Double = 0

                for scan in profile.diskScans {
                    let sizeMB = self.estimateDirectorySize(path: scan.path)
                    diskSizes[scan.label] = sizeMB
                    totalDisk += sizeMB
                }

                states.append(ProfileState(
                    id: profile.id,
                    profile: profile,
                    isDetected: true,
                    isRunning: isRunning,
                    memoryMB: memoryMB,
                    diskSizes: diskSizes,
                    totalDiskMB: totalDisk,
                    lastUpdated: Date()
                ))
            }

            DispatchQueue.main.async {
                self.profileStates = states
                self.isRefreshing = false
            }
        }
    }

    func executeAction(_ action: DeveloperProfile.CleanupAction) async -> (success: Bool, output: String) {
        return await withCheckedContinuation { continuation in
            workQueue.async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/bin/zsh")
                task.arguments = ["-c", action.shellCommand]
                let outPipe = Pipe()
                let errPipe = Pipe()
                task.standardOutput = outPipe
                task.standardError = errPipe
                do {
                    try task.run()
                    task.waitUntilExit()
                    let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                    let success = task.terminationStatus == 0
                    continuation.resume(returning: (success, success ? out : err))
                } catch {
                    continuation.resume(returning: (false, error.localizedDescription))
                }
            }
        }
    }

    func addCustomRule(_ rule: CustomRule) {
        customRules.append(rule)
        saveCustomRules()
    }

    func removeCustomRule(id: UUID) {
        customRules.removeAll { $0.id == id }
        saveCustomRules()
    }

    // MARK: - Private

    private func detect(_ method: DeveloperProfile.DetectMethod) -> Bool {
        switch method {
        case .always: return true
        case .processName(let name):
            return runShellStatus("pgrep -qx '\(name)'") == 0
        case .bundleID(let id):
            return NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == id }
                || NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) != nil
        case .commandExists(let cmd):
            return runShellStatus("which \(cmd)") == 0
        case .directoryExists(let path):
            let expanded = (path as NSString).expandingTildeInPath
            return FileManager.default.fileExists(atPath: expanded)
        }
    }

    private func isRunning(_ profile: DeveloperProfile, psOutput: String) -> Bool {
        for pattern in profile.memoryProcessPatterns {
            if psOutput.lowercased().contains(pattern.lowercased()) { return true }
        }
        return false
    }

    private func measureMemory(_ profile: DeveloperProfile, psOutput: String) -> Double {
        var total: Double = 0
        for line in psOutput.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            for pattern in profile.memoryProcessPatterns {
                if trimmed.lowercased().contains(pattern.lowercased()) {
                    let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
                    if let rssKB = Double(parts.first ?? "") {
                        total += rssKB / 1024
                    }
                }
            }
        }
        return total
    }

    private func estimateDirectorySize(path: String) -> Double {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else { return 0 }
        var totalBytes: Int64 = 0
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: expanded),
            includingPropertiesForKeys: [.fileSizeKey, .isDirectoryKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return 0 }
        
        var count = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isDirectoryKey]),
                  values.isDirectory == false else { continue }
            totalBytes += Int64(values.fileSize ?? 0)
            count += 1
            if count > 50_000 { break }
        }
        return Double(totalBytes) / (1024 * 1024)
    }

    private func runPS() -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/ps")
        task.arguments = ["-axo", "rss=,command="]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    @discardableResult
    private func runShell(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    private func runShellStatus(_ command: String) -> Int32 {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
        task.waitUntilExit()
        return task.terminationStatus
    }

    private func loadCustomRules() {
        if let data = UserDefaults.standard.data(forKey: "customDevRules"),
           let decoded = try? JSONDecoder().decode([CustomRule].self, from: data) {
            customRules = decoded
        }
    }

    private func saveCustomRules() {
        if let encoded = try? JSONEncoder().encode(customRules) {
            UserDefaults.standard.set(encoded, forKey: "customDevRules")
        }
    }
}