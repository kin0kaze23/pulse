//
//  CronJobScanner.swift
//  Pulse
//
//  Scans cron jobs for security analysis
//  Malware often uses cron jobs for persistence
//

import Foundation
import SwiftUI

// MARK: - Cron Job Model

struct CronJob: Identifiable {
    let id = UUID()
    let name: String
    let schedule: String
    let command: String
    let user: String
    let source: CronSource
    let riskLevel: RiskLevel
    
    enum CronSource: String {
        case userCrontab = "User Crontab"
        case systemCrontab = "System Crontab"
        case cronD = "cron.d"
        case cronHourly = "cron.hourly"
        case cronDaily = "cron.daily"
        case cronWeekly = "cron.weekly"
        case cronMonthly = "cron.monthly"
        
        var icon: String {
            switch self {
            case .userCrontab: return "person"
            case .systemCrontab: return "gear"
            case .cronD: return "folder"
            case .cronHourly: return "clock"
            case .cronDaily: return "sun.max"
            case .cronWeekly: return "calendar"
            case .cronMonthly: return "calendar.badge.clock"
            }
        }
    }
    
    enum RiskLevel {
        case safe
        case unknown
        case suspicious
        case dangerous
        
        var color: Color {
            switch self {
            case .safe: return .green
            case .unknown: return .gray
            case .suspicious: return .orange
            case .dangerous: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .safe: return "checkmark.circle"
            case .unknown: return "questionmark.circle"
            case .suspicious: return "exclamationmark.triangle"
            case .dangerous: return "xmark.octagon"
            }
        }
    }
    
    var scheduleDescription: String {
        // Parse common cron schedules
        let parts = schedule.split(separator: " ")
        guard parts.count >= 5 else { return schedule }
        
        let minute = String(parts[0])
        let hour = String(parts[1])
        let dayOfMonth = String(parts[2])
        let month = String(parts[3])
        let dayOfWeek = String(parts[4])
        
        // Common patterns
        if minute == "*" && hour == "*" { return "Every minute" }
        if minute == "0" && hour == "*" { return "Every hour" }
        if minute == "0" && hour != "*" { return "Daily at \(hour):00" }
        if minute == "0" && hour == "0" { return "Daily at midnight" }
        if dayOfWeek != "*" && hour != "*" { return "Weekly on day \(dayOfWeek) at \(hour):\(minute)" }
        
        return schedule
    }
}

// MARK: - Cron Job Scanner

class CronJobScanner: ObservableObject {
    static let shared = CronJobScanner()
    
    @Published var jobs: [CronJob] = []
    @Published var isScanning = false
    @Published var scanProgress: Double = 0
    @Published var lastScanDate: Date?
    @Published var jobsBySource: [CronJob.CronSource: [CronJob]] = [:]
    
    // MARK: - Scan
    
    func scan() {
        guard !isScanning else { return }
        
        DispatchQueue.main.async {
            self.isScanning = true
            self.scanProgress = 0
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            var allJobs: [CronJob] = []
            var progress = 0.0
            let totalSteps = 7.0
            
            // 1. User crontab
            if let userJobs = self.scanUserCrontab() {
                allJobs.append(contentsOf: userJobs)
            }
            progress += 1
            DispatchQueue.main.async { self.scanProgress = progress / totalSteps }
            
            // 2. System crontab
            if let systemJobs = self.scanSystemCrontab() {
                allJobs.append(contentsOf: systemJobs)
            }
            progress += 1
            DispatchQueue.main.async { self.scanProgress = progress / totalSteps }
            
            // 3-7. Cron directories
            let cronDirs: [(CronJob.CronSource, String)] = [
                (.cronD, "/etc/cron.d"),
                (.cronHourly, "/etc/cron.hourly"),
                (.cronDaily, "/etc/cron.daily"),
                (.cronWeekly, "/etc/cron.weekly"),
                (.cronMonthly, "/etc/cron.monthly")
            ]
            
            for (source, path) in cronDirs {
                if let dirJobs = self.scanCronDirectory(path: path, source: source) {
                    allJobs.append(contentsOf: dirJobs)
                }
                progress += 1
                DispatchQueue.main.async { self.scanProgress = progress / totalSteps }
            }
            
            // Group by source
            let grouped = Dictionary(grouping: allJobs) { $0.source }
            
            DispatchQueue.main.async {
                self.jobs = allJobs
                self.jobsBySource = grouped
                self.lastScanDate = Date()
                self.isScanning = false
                self.scanProgress = 1.0
            }
        }
    }
    
    // MARK: - Scan Methods
    
    private func scanUserCrontab() -> [CronJob]? {
        let output = runCommand("crontab -l 2>/dev/null")
        guard !output.isEmpty else { return nil }
        
        return parseCrontabOutput(output, source: .userCrontab, user: NSUserName())
    }
    
    private func scanSystemCrontab() -> [CronJob]? {
        let path = "/etc/crontab"
        guard let content = try? String(contentsOfFile: path) else { return nil }
        
        return parseCrontabOutput(content, source: .systemCrontab, user: "root")
    }
    
    private func scanCronDirectory(path: String, source: CronJob.CronSource) -> [CronJob]? {
        guard let items = try? FileManager.default.contentsOfDirectory(atPath: path) else { return nil }
        
        var jobs: [CronJob] = []
        
        for item in items {
            // Skip hidden files and directories
            if item.hasPrefix(".") { continue }
            
            let itemPath = (path as NSString).appendingPathComponent(item)
            
            // Read the script content
            if let content = try? String(contentsOfFile: itemPath) {
                let riskLevel = assessScriptRisk(content)
                
                jobs.append(CronJob(
                    name: item,
                    schedule: source.rawValue.contains("hourly") ? "Hourly" :
                              source.rawValue.contains("daily") ? "Daily" :
                              source.rawValue.contains("weekly") ? "Weekly" :
                              source.rawValue.contains("monthly") ? "Monthly" : "Custom",
                    command: content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(100) + "...",
                    user: "root",
                    source: source,
                    riskLevel: riskLevel
                ))
            }
        }
        
        return jobs.isEmpty ? nil : jobs
    }
    
    private func parseCrontabOutput(_ output: String, source: CronJob.CronSource, user: String) -> [CronJob]? {
        var jobs: [CronJob] = []
        
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            
            // Parse crontab line (minute hour day month weekday command)
            let parts = trimmed.split(separator: " ", maxSplits: 5)
            guard parts.count >= 6 else { continue }
            
            let schedule = parts[0...4].map(String.init).joined(separator: " ")
            let command = String(parts[5])
            
            let riskLevel = assessCommandRisk(command)
            
            jobs.append(CronJob(
                name: command.split(separator: " ").first.map(String.init) ?? "Unknown",
                schedule: schedule,
                command: command,
                user: user,
                source: source,
                riskLevel: riskLevel
            ))
        }
        
        return jobs.isEmpty ? nil : jobs
    }
    
    // MARK: - Risk Assessment
    
    private func assessCommandRisk(_ command: String) -> CronJob.RiskLevel {
        let lowercased = command.lowercased()
        
        // Dangerous patterns
        let dangerousPatterns = ["curl", "wget", "nc -", "bash -i", "python -c", "perl -e", "rm -rf"]
        for pattern in dangerousPatterns {
            if lowercased.contains(pattern) {
                return .dangerous
            }
        }
        
        // Suspicious patterns
        let suspiciousPatterns = ["eval", "exec", "base64", "openssl", "/tmp/"]
        for pattern in suspiciousPatterns {
            if lowercased.contains(pattern) {
                return .suspicious
            }
        }
        
        // Known safe commands
        let safeCommands = ["backup", "rsync", "logrotate", "updatedb", "apt", "brew"]
        for safe in safeCommands {
            if lowercased.contains(safe) {
                return .safe
            }
        }
        
        return .unknown
    }
    
    private func assessScriptRisk(_ content: String) -> CronJob.RiskLevel {
        return assessCommandRisk(content)
    }
    
    // MARK: - Helpers
    
    private func runCommand(_ command: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/zsh")
        task.arguments = ["-c", command]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        
        try? task.run()
        task.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    // MARK: - Summary
    
    var totalJobs: Int { jobs.count }
    var suspiciousCount: Int { jobs.filter { $0.riskLevel == .suspicious || $0.riskLevel == .dangerous }.count }
}