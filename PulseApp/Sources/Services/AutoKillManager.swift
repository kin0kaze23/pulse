import Foundation
import AppKit

/// Automatically monitors and can kill processes that exceed resource thresholds
class AutoKillManager: ObservableObject {
    static let shared = AutoKillManager()

    @Published var isEnabled = false
    @Published var whitelistedProcesses: [String] = []
    @Published var killLog: [KillLogEntry] = []
    @Published var autoKillMemoryThresholdGB: Double = 5.0
    @Published var autoKillCPUThresholdPercent: Double = 90.0
    @Published var warningBeforeKill: Bool = true
    @Published var monitoredProcesses: [RunawayCandidate] = []

    private var warningTimers: [Int32: Timer] = [:]
    private var settings: AppSettings { AppSettings.shared }

    struct KillLogEntry: Identifiable {
        let id = UUID()
        let processName: String
        let pid: Int32
        let reason: String
        let timestamp: Date
        let memoryGB: Double
        let wasAutoKilled: Bool
    }

    struct RunawayCandidate: Identifiable {
        let id: Int32
        let name: String
        let memoryGB: Double
        let cpuPercent: Double
        let threat: ThreatLevel

        enum ThreatLevel: String {
            case warning = "Warning"
            case severe = "Severe"
            case critical = "Critical"

            var color: String {
                switch self {
                case .warning: return "orange"
                case .severe: return "red"
                case .critical: return "purple"
                }
            }
        }
    }

    private init() {
        loadWhitelist()
    }

    // MARK: - Check Processes

    func checkProcesses() {
        guard isEnabled else { return }

        let processMonitor = ProcessMemoryMonitor.shared
        let cpuMonitor = CPUMonitor.shared
        var candidates: [RunawayCandidate] = []

        for process in processMonitor.allProcesses {
            guard !isWhitelisted(process.name) else { continue }

            let memGB = Double(process.memoryBytes) / (1024 * 1024 * 1024)
            let cpuPct = cpuMonitor.topCPUProcesses.first(where: { $0.id == process.id })?.cpuPercentage ?? 0

            var threat: RunawayCandidate.ThreatLevel?
            var reason = ""

            if memGB >= autoKillMemoryThresholdGB * 2 {
                threat = .critical
                reason = "Using \(String(format: "%.1f", memGB))GB memory (critical threshold)"
            } else if memGB >= autoKillMemoryThresholdGB {
                threat = .severe
                reason = "Using \(String(format: "%.1f", memGB))GB memory"
            } else if cpuPct >= autoKillCPUThresholdPercent {
                threat = .severe
                reason = "Using \(String(format: "%.0f", cpuPct))% CPU"
            } else if memGB >= autoKillMemoryThresholdGB * 0.6 || cpuPct >= autoKillCPUThresholdPercent * 0.6 {
                threat = .warning
                reason = "Elevated resource usage"
            }

            if let threat = threat {
                candidates.append(RunawayCandidate(
                    id: process.id,
                    name: process.name,
                    memoryGB: memGB,
                    cpuPercent: cpuPct,
                    threat: threat
                ))

                if threat == .critical {
                    if warningBeforeKill {
                        showWarning(for: process, reason: reason, memGB: memGB)
                    } else {
                        killProcess(pid: process.id, name: process.name, reason: reason, memoryGB: memGB)
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.monitoredProcesses = candidates
        }
    }

    // MARK: - Kill

    func killProcess(pid: Int32, name: String, reason: String, memoryGB: Double) {
        let result = Darwin.kill(pid, SIGTERM)

        let entry = KillLogEntry(
            processName: name,
            pid: pid,
            reason: reason,
            timestamp: Date(),
            memoryGB: memoryGB,
            wasAutoKilled: true
        )

        DispatchQueue.main.async {
            self.killLog.insert(entry, at: 0)
            if self.killLog.count > 100 {
                self.killLog.removeLast()
            }
        }

        if result != 0 {
            // Force kill if SIGTERM failed
            Darwin.kill(pid, SIGKILL)
        }
    }

    // MARK: - Warning

    private func showWarning(for process: ProcessMemoryInfo, reason: String, memGB: Double) {
        // Avoid repeated warnings for same process
        guard warningTimers[process.id] == nil else { return }

        let content = NSAlert()
        content.messageText = "⚠️ Runaway Process Detected"
        content.informativeText = "\"\(process.name)\" is using \(String(format: "%.1f", memGB))GB. \(reason).\n\nWould you like to terminate it?"
        content.alertStyle = .warning
        content.addButton(withTitle: "Kill Process")
        content.addButton(withTitle: "Ignore")
        content.addButton(withTitle: "Add to Whitelist")

        let response = content.runModal()

        switch response {
        case .alertFirstButtonReturn:
            killProcess(pid: process.id, name: process.name, reason: reason, memoryGB: memGB)
        case .alertThirdButtonReturn:
            addToWhitelist(process.name)
        default:
            break
        }

        // Cooldown
        warningTimers[process.id] = Timer.scheduledTimer(withTimeInterval: 300, repeats: false) { [weak self] _ in
            self?.warningTimers.removeValue(forKey: process.id)
        }
    }

    // MARK: - Whitelist

    func isWhitelisted(_ name: String) -> Bool {
        whitelistedProcesses.contains { name.localizedCaseInsensitiveContains($0) }
    }

    func addToWhitelist(_ name: String) {
        guard !whitelistedProcesses.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        whitelistedProcesses.append(name)
        saveWhitelist()
    }

    func removeFromWhitelist(_ name: String) {
        whitelistedProcesses.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        saveWhitelist()
    }

    private func saveWhitelist() {
        UserDefaults.standard.set(whitelistedProcesses, forKey: "autoKillWhitelist")
    }

    private func loadWhitelist() {
        // Default whitelist - critical system processes that should NEVER be killed
        // Users can add more, but these are protected by default
        whitelistedProcesses = UserDefaults.standard.stringArray(forKey: "autoKillWhitelist") ?? [
            // Core macOS processes
            "Finder", "WindowServer", "kernel_task", "launchd", "loginwindow",
            "Dock", "SystemUIServer", "Spotlight", "mds", "corespotlightd",
            
            // System services
            "distnoted", "cfprefsd", "usernoted", "syslogd", "opendirectoryd",
            "configd", "powerd", "thermald", "bluetoothd", "airportd",
            "networkd", "mDNSResponder", "discoveryd", "locationd",
            
            // Input and accessibility
            "coreauthd", "securityd", "trustd", "seserviced", "tccd",
            "accessibilityd", "hidd", "MouseKeys", "SlowKeys", "StickyKeys",
            
            // Audio and media
            "coreaudiod", "audioanalysisd", "mediaserverd", "VTDecoderXPCService",
            
            // Power and battery
            "PMHeart", "powerd", "batteryd", "thermald",
            
            // File system
            "diskarbitrationd", "fseventsd", "storagekitd", "diskimages-helper",
            "fsck", "mount", "umount",
            
            // iCloud and sync
            "bird", "cloudd", "accountsd", "syncdefaultsd",
            
            // Time Machine
            "backupd", "MobileTimeMachine",
            
            // Search and indexing
            "mds", "mds_stores", "mdworker", "mdworker_ls", "mdworker_shared",
            
            // Notification and alerts
            "usernoted", "alertuserd", "NotificationCenter",
            
            // Printing
            "cupsd", "cups-notifier", "printtool",
            
            // Remote and sharing
            "ssh", "sshd", "screensharingd", "ARDAgent", "remoteinstall",
            
            // Virtualization and containers
            "qemu", "docker", "containerd", "hyperkit", "com.docker",
            
            // Development tools (protect from accidental kill)
            "Xcode", "codesign", "productbuild", "pkgbuild",
            
            // Third-party security tools (should not be killed)
            "Little Snitch", "LuLu", "KnockKnock", "BlockBlock", "Objective-See"
        ]
    }

    // MARK: - Clear Log

    func clearLog() {
        killLog.removeAll()
    }
}
