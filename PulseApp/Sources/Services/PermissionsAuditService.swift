import Foundation
import AppKit

/// FDA Request State
enum FDARequestState: Equatable {
    case notRequested
    case requesting
    case granted
    case denied
    case openSettings

    var description: String {
        switch self {
        case .notRequested:
            return "Full Disk Access not granted"
        case .requesting:
            return "Requesting access..."
        case .granted:
            return "Full Disk Access granted"
        case .denied:
            return "Access denied - please grant manually"
        case .openSettings:
            return "Open System Settings to grant access"
        }
    }
}

/// Extended permissions audit service for Phase 3.3
/// Reads TCC database to show app permissions across the system
class PermissionsAuditService: ObservableObject {
    static let shared = PermissionsAuditService()

    // MARK: - Published Properties

    @Published private(set) var appPermissions: [String: [AppPermissionInfo]] = [:]
    @Published private(set) var isScanning: Bool = false
    @Published private(set) var scanProgress: String = "Ready"
    @Published private(set) var fdaStatus: FDARequestState = .notRequested

    // MARK: - Private Properties

    private let fileManager = FileManager.default

    /// TCC database paths (user and system)
    private var tccDatabasePaths: [String] {
        var paths = [
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"
        ]

        // System TCC (requires root)
        if fileManager.fileExists(atPath: "/Library/Application Support/com.apple.TCC/TCC.db") {
            paths.append("/Library/Application Support/com.apple.TCC/TCC.db")
        }

        return paths
    }

    // MARK: - Initialization

    private init() {
        checkFDAStatus()
    }

    // MARK: - Public Methods

    /// Check Full Disk Access status
    func checkFDAStatus() {
        let testPath = NSHomeDirectory() + "/Library/Mail"

        do {
            // Try to access a protected folder
            _ = try fileManager.contentsOfDirectory(atPath: testPath)
            fdaStatus = .granted
        } catch {
            fdaStatus = .denied
        }
    }

    /// Scan for all app permissions from TCC database
    func scanPermissions() {
        guard !isScanning else { return }

        isScanning = true
        scanProgress = "Checking TCC database access..."
        appPermissions = [:]

        // Check FDA status first
        checkFDAStatus()

        guard fdaStatus == .granted else {
            scanProgress = "Full Disk Access required"
            isScanning = false
            return
        }

        scanProgress = "Scanning installed applications..."

        // Get list of installed apps
        let applicationsPath = "/Applications"
        let homeApplicationsPath = NSHomeDirectory() + "/Applications"

        var appsToScan: [(path: String, name: String)] = []

        // Scan /Applications
        if let contents = try? fileManager.contentsOfDirectory(atPath: applicationsPath) {
            for item in contents where item.hasSuffix(".app") {
                let path = "\(applicationsPath)/\(item)"
                appsToScan.append((path: path, name: item.replacingOccurrences(of: ".app", with: "")))
            }
        }

        // Scan ~/Applications
        if let contents = try? fileManager.contentsOfDirectory(atPath: homeApplicationsPath) {
            for item in contents where item.hasSuffix(".app") {
                let path = "\(homeApplicationsPath)/\(item)"
                appsToScan.append((path: path, name: item.replacingOccurrences(of: ".app", with: "")))
            }
        }

        scanProgress = "Reading permissions for \(appsToScan.count) apps..."

        // For each app, check what permissions it has
        for app in appsToScan {
            if let bundle = Bundle(path: app.path),
               let bundleID = bundle.bundleIdentifier {
                let permissions = getPermissionsForApp(bundleIdentifier: bundleID)
                if !permissions.isEmpty {
                    appPermissions[bundleID] = permissions
                }
            }
        }

        scanProgress = "Scan complete - \(appPermissions.count) apps with permissions"
        isScanning = false
    }

    /// Get permissions for a specific app
    func getPermissionsForApp(bundleIdentifier: String) -> [AppPermissionInfo] {
        var permissions: [AppPermissionInfo] = []

        // Check various TCC service permissions
        let servicesToCheck: [(service: String, type: PermissionInfoType)] = [
            ("kTCCServiceAccessibility", .accessibility),
            ("kTCCServiceCamera", .camera),
            ("kTCCServiceMicrophone", .microphone),
            ("kTCCServiceScreenCapture", .screenRecording),
            ("kTCCServiceContacts", .contacts),
            ("kTCCServiceCalendar", .calendar),
            ("kTCCServiceReminders", .reminders),
            ("kTCCServiceLocation", .location),
            ("kTCCServiceSpeechRecognition", .speechRecognition),
            ("kTCCServiceAutomation", .automation),
            ("kTCCServiceInputMonitoring", .inputMonitoring)
        ]

        for (service, type) in servicesToCheck {
            let status = checkTCCPermission(service: service, bundleIdentifier: bundleIdentifier)
            if status != .unknown {
                permissions.append(AppPermissionInfo(
                    bundleIdentifier: bundleIdentifier,
                    appName: getAppName(bundleIdentifier: bundleIdentifier),
                    permissionType: type,
                    status: status
                ))
            }
        }

        return permissions
    }

    /// Cancel ongoing scan
    func cancelScan() {
        isScanning = false
        scanProgress = "Scan cancelled"
    }

    /// Open System Settings to the Privacy & Security pane
    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Request Full Disk Access by opening System Settings
    func requestFDA() {
        fdaStatus = .requesting
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
        // Check status after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.checkFDAStatus()
        }
    }

    // MARK: - Private Methods

    /// Check TCC database for a specific permission
    private func checkTCCPermission(service: String, bundleIdentifier: String) -> PermissionStatus {
        let tccPath = NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db"

        guard fileManager.fileExists(atPath: tccPath) else {
            return .unknown
        }

        // Use sqlite3 to query TCC database
        // This is a simplified check - real implementation would use proper SQLite queries
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        task.arguments = [
            tccPath,
            "SELECT allowed FROM access WHERE service='\(service)' AND client='\(bundleIdentifier)'"
        ]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = FileHandle.nullDevice

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                if output == "1" {
                    return .granted
                } else if output == "0" {
                    return .missing
                }
            }
        } catch {
            // Silently fail - TCC access might be restricted
        }

        return .unknown
    }

    /// Get app name from bundle identifier
    private func getAppName(bundleIdentifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            if let bundle = Bundle(url: url),
               let name = bundle.infoDictionary?["CFBundleName"] as? String {
                return name
            }
            return url.deletingPathExtension().lastPathComponent
        }
        return bundleIdentifier
    }
}

// MARK: - Permission Info Type

enum PermissionInfoType: String, CaseIterable, Identifiable {
    case accessibility = "Accessibility"
    case camera = "Camera"
    case microphone = "Microphone"
    case screenRecording = "Screen Recording"
    case contacts = "Contacts"
    case calendar = "Calendar"
    case reminders = "Reminders"
    case location = "Location"
    case speechRecognition = "Speech Recognition"
    case automation = "Automation"
    case inputMonitoring = "Input Monitoring"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .accessibility: return "person.crop.circle.badge.checkmark"
        case .camera: return "video"
        case .microphone: return "mic"
        case .screenRecording: return "rectangle.on.rectangle"
        case .contacts: return "person.crop.circle"
        case .calendar: return "calendar"
        case .reminders: return "bell"
        case .location: return "location"
        case .speechRecognition: return "waveform"
        case .automation: return "gearshape.2"
        case .inputMonitoring: return "keyboard"
        }
    }

    var color: String {
        switch self {
        case .accessibility, .inputMonitoring: return "red"
        case .camera, .microphone, .screenRecording: return "red"
        case .contacts, .calendar, .reminders, .location: return "blue"
        case .speechRecognition: return "purple"
        case .automation: return "blue"
        }
    }
}

// MARK: - App Permission Info

struct AppPermissionInfo: Identifiable {
    let id = UUID()
    let bundleIdentifier: String
    let appName: String
    let permissionType: PermissionInfoType
    let status: PermissionStatus
}