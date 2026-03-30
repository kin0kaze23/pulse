//
//  PermissionsService.swift
//  Pulse
//
//  Permission diagnostics and status checking
//  Shows exactly which permissions Pulse needs, why, and how to enable them
//

import Foundation
import AppKit
import UserNotifications
import AppKit

// MARK: - Permission Models

/// Permission status
enum PermissionStatus: String, CaseIterable {
    case granted = "Granted"
    case missing = "Missing"
    case unknown = "Unknown"
    case verificationPending = "Needs Verification"

    var color: String {
        switch self {
        case .granted: return "green"
        case .missing: return "orange"
        case .unknown: return "gray"
        case .verificationPending: return "yellow"
        }
    }

    var icon: String {
        switch self {
        case .granted: return "checkmark.circle.fill"
        case .missing: return "exclamationmark.triangle.fill"
        case .unknown: return "questionmark.circle.fill"
        case .verificationPending: return "exclamationmark.circle.fill"
        }
    }

    var isGranted: Bool {
        self == .granted
    }

    var isMissing: Bool {
        self == .missing
    }
}

/// Permission type
enum PermissionType: String, CaseIterable {
    case fullDiskAccess = "Full Disk Access"
    case accessibility = "Accessibility"
    case notifications = "Notifications"
    case appleEvents = "Apple Events"

    var identifier: String {
        switch self {
        case .fullDiskAccess: return "full-disk-access"
        case .accessibility: return "accessibility"
        case .notifications: return "notifications"
        case .appleEvents: return "apple-events"
        }
    }
}

/// Permission info model
struct PermissionInfo: Identifiable, Equatable {
    let id = UUID()
    let type: PermissionType
    let status: PermissionStatus
    let whyNeeded: String
    let affectedFeatures: [String]
    let howToEnable: String

    var isGranted: Bool {
        status == .granted
    }

    var isMissing: Bool {
        status == .missing
    }

    static func == (lhs: PermissionInfo, rhs: PermissionInfo) -> Bool {
        lhs.type == rhs.type && lhs.status == rhs.status
    }
}

// MARK: - Permission Change Event

/// Represents a permission change for toast notification
struct PermissionChangeEvent {
    let type: PermissionType
    let from: PermissionStatus
    let to: PermissionStatus
    let wasGranted: Bool
}

// MARK: - Permissions Service

/// Service for checking and managing Pulse permissions
class PermissionsService: ObservableObject {
    static let shared = PermissionsService()

    @Published var permissions: [PermissionInfo] = []
    @Published var isChecking = false
    @Published var lastChecked: Date?
    @Published var permissionsChanged = false
    @Published var recentChange: PermissionChangeEvent?

    // Store previous permissions for change detection
    private var previousPermissions: [PermissionType: PermissionStatus] = [:]

    private init() {}

    // MARK: - Public API

    /// Check all permissions and update status
    func checkAllPermissions() {
        isChecking = true

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var permissions: [PermissionInfo] = []

            // Check each permission
            permissions.append(self.checkFullDiskAccess())
            permissions.append(self.checkAccessibility())
            permissions.append(self.checkNotifications())
            permissions.append(self.checkAppleEvents())

            DispatchQueue.main.async {
                // Detect changes
                self.detectPermissionChanges(permissions)
                self.permissions = permissions
                self.lastChecked = Date()
                self.isChecking = false
            }
        }
    }

    /// Check permissions silently (for auto-refresh on app activation)
    func checkAllPermissionsSilently() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var permissions: [PermissionInfo] = []
            permissions.append(self.checkFullDiskAccess())
            permissions.append(self.checkAccessibility())
            permissions.append(self.checkNotifications())
            permissions.append(self.checkAppleEvents())

            DispatchQueue.main.async {
                self.detectPermissionChanges(permissions)
                self.permissions = permissions
                self.lastChecked = Date()
            }
        }
    }

    /// Open System Settings to enable a specific permission
    func openSettings(for permission: PermissionType) {
        switch permission {
        case .fullDiskAccess:
            openFullDiskAccessSettings()
        case .accessibility:
            openAccessibilitySettings()
        case .notifications:
            openNotificationSettings()
        case .appleEvents:
            openAppleEventsSettings()
        }
    }

    // MARK: - Permission Checks

    private func checkFullDiskAccess() -> PermissionInfo {
        let status = checkFullDiskAccessStatus()

        return PermissionInfo(
            type: PermissionType.fullDiskAccess,
            status: status,
            whyNeeded: "Pulse needs Full Disk Access to scan system directories for security threats and access certain cache locations.",
            affectedFeatures: [
                "Security scanner (LaunchAgents, LaunchDaemons)",
                "Deep file system analysis",
                "Complete cleanup operations"
            ],
            howToEnable: "Open System Settings → Privacy & Security → Full Disk Access → Enable Pulse"
        )
    }

    private func checkAccessibility() -> PermissionInfo {
        let status = hasAccessibility() ? PermissionStatus.granted : PermissionStatus.missing

        return PermissionInfo(
            type: PermissionType.accessibility,
            status: status,
            whyNeeded: "Pulse requests Accessibility permission to detect apps with keyboard monitoring capabilities for security scanning.",
            affectedFeatures: [
                "Suspicious process scanner",
                "Keylogger detection",
                "Security threat detection"
            ],
            howToEnable: "Open System Settings → Privacy & Security → Accessibility → Enable Pulse"
        )
    }

    private func checkNotifications() -> PermissionInfo {
        let status = hasNotifications()

        return PermissionInfo(
            type: PermissionType.notifications,
            status: status,
            whyNeeded: "Pulse uses notifications to alert you when memory, CPU, or disk usage exceeds configured thresholds.",
            affectedFeatures: [
                "Memory threshold alerts",
                "CPU overload warnings",
                "Disk space notifications"
            ],
            howToEnable: "Open System Settings → Notifications → Pulse → Enable Notifications"
        )
    }

    private func checkAppleEvents() -> PermissionInfo {
        let status = checkAppleEventsStatus()

        return PermissionInfo(
            type: PermissionType.appleEvents,
            status: status,
            whyNeeded: "Pulse uses Apple Events to count browser tabs and manage applications for optimization features.",
            affectedFeatures: [
                "Browser tab counting",
                "App management features",
                "Smart suggestions"
            ],
            howToEnable: "Open System Settings → Privacy & Security → Automation → Pulse → Enable target apps"
        )
    }

    // MARK: - Permission Status Checks

    /// Check Full Disk Access with multi-verification
    /// Returns .verificationPending if checks disagree
    private func checkFullDiskAccessStatus() -> PermissionStatus {
        // Primary check: TCC database path (most reliable indicator)
        let tccPath = "/Library/Application Support/com.apple.TCC"
        let canReadTCC = FileManager.default.isReadableFile(atPath: tccPath)

        // Secondary check: /Library/Logs (also protected)
        let logsPath = "/Library/Logs"
        let canReadLogs = FileManager.default.isReadableFile(atPath: logsPath)

        // Tertiary check: try to enumerate /Library (requires FDA)
        let libraryPath = "/Library"
        var canEnumerateLibrary = false
        if let enumerator = FileManager.default.enumerator(atPath: libraryPath) {
            // If we can enumerate, we likely have FDA
            let _ = enumerator.nextObject()
            canEnumerateLibrary = true
        }

        // Decision logic - require 2/3 agreement to avoid false positives:
        // - 2-3 positive = granted (strong signal)
        // - 1 positive = verification pending (ambiguous)
        // - 0 positive = missing (clear failure)
        let positiveChecks = [canReadTCC, canReadLogs, canEnumerateLibrary].filter { $0 }.count

        if positiveChecks >= 2 {
            // Strong signal: at least 2 checks agree
            return .granted
        } else if positiveChecks == 1 {
            // Ambiguous: only 1 check passed - be honest about uncertainty
            return .verificationPending
        } else {
            // Clear failure: all checks failed
            return .missing
        }
    }

    private func hasAccessibility() -> Bool {
        return AXIsProcessTrusted()
    }

    private func hasNotifications() -> PermissionStatus {
        // Check notification center authorization status
        let group = DispatchGroup()
        group.enter()

        var status: PermissionStatus = .unknown

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                status = .granted
            case .denied:
                status = .missing
            case .notDetermined:
                status = .missing
            case .provisional:
                status = .granted
            case .ephemeral:
                status = .granted
            @unknown default:
                status = .unknown
            }
            group.leave()
        }

        // Wait up to 1 second for response
        let result = group.wait(timeout: .now() + 1.0)
        if result == .timedOut {
            return .unknown
        }

        return status
    }

    /// Check Apple Events by sending a harmless event to Finder
    /// Returns .unknown if timeout or error
    /// Uses background queue to ensure no UI blocking
    private func checkAppleEventsStatus() -> PermissionStatus {
        let group = DispatchGroup()
        group.enter()

        var status: PermissionStatus = .unknown

        // Use explicit background queue for AppleScript execution
        DispatchQueue.global(qos: .utility).async {
            // Send harmless read-only Apple Event to Finder
            // This is safe and doesn't modify any state
            let script = NSAppleScript(source: "tell application \"Finder\" to name")

            var error: NSDictionary?
            let _ = script?.executeAndReturnError(&error)

            if let error = error {
                // NSAppleScript error dictionary contains "NSAppleScriptErrorMessage"
                // Error codes for Apple Events: -1744 (not authorized), -10000 (generic)
                // Check if error message mentions permission/authorization
                let errorMessage = error["NSAppleScriptErrorMessage"] as? String ?? ""
                if errorMessage.lowercased().contains("permission") ||
                   errorMessage.lowercased().contains("not allowed") ||
                   errorMessage.lowercased().contains("access") {
                    status = .missing
                } else {
                    // Other errors (Finder not running, etc.) = unknown
                    // Don't claim "missing" when Finder is just not available
                    status = .unknown
                }
            } else {
                // Success - Apple Events granted
                status = .granted
            }

            group.leave()
        }

        // Wait up to 2 seconds for response
        // This is a hard timeout - will not block longer
        let result = group.wait(timeout: .now() + 2.0)
        if result == .timedOut {
            return .unknown
        }

        return status
    }

    // MARK: - Change Detection

    /// Detect if any permission status has changed and publish notification
    private func detectPermissionChanges(_ newPermissions: [PermissionInfo]) {
        var changed = false
        var mostSignificantChange: PermissionChangeEvent?

        for permission in newPermissions {
            if let previousStatus = previousPermissions[permission.type] {
                if previousStatus != permission.status {
                    changed = true
                    print("[PermissionsService] Permission changed: \(permission.type.rawValue) from \(previousStatus.rawValue) to \(permission.status.rawValue)")

                    // Track the most significant change (prioritize grants over revocations)
                    let wasGranted = permission.status == .granted
                    let change = PermissionChangeEvent(
                        type: permission.type,
                        from: previousStatus,
                        to: permission.status,
                        wasGranted: wasGranted
                    )

                    // Keep the most significant change for toast
                    // Priority: grant > missing > verificationPending > unknown
                    if mostSignificantChange == nil || wasGranted {
                        mostSignificantChange = change
                    }
                }
            }
            previousPermissions[permission.type] = permission.status
        }

        if changed {
            permissionsChanged = true
            recentChange = mostSignificantChange

            // Reset flag after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                self?.permissionsChanged = false
                self?.recentChange = nil
            }
        }
    }

    // MARK: - Open Settings

    private func openFullDiskAccessSettings() {
        // macOS Sonoma+
        if let url = URL(string: "x-apple.systempreferences:com.apple.PrivacySettings") {
            NSWorkspace.shared.open(url)
        }
        // Older macOS
        else if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openNotificationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func openAppleEventsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Helper Extension

extension PermissionsService {
    /// Get summary of permission status
    var permissionSummary: String {
        let granted = permissions.filter { $0.isGranted }.count
        let total = permissions.count

        if granted == total {
            return "All permissions granted"
        } else {
            let missing = total - granted
            return "\(missing) permission\(missing == 1 ? "" : "s") need attention"
        }
    }

    /// Check if any critical permissions are missing
    var hasCriticalPermissionsMissing: Bool {
        permissions.contains { $0.isMissing && ($0.type == .fullDiskAccess || $0.type == .accessibility) }
    }

    /// Get permission-dependent feature status
    func featureStatus(for feature: String) -> (available: Bool, reason: String?) {
        switch feature {
        case "securityScan":
            let fda = permissions.first { $0.type == .fullDiskAccess }
            if let fda = fda, fda.isGranted {
                return (true, nil)
            } else if let fda = fda, fda.status == .verificationPending {
                return (false, "Full Disk Access needs verification")
            } else {
                return (false, "Full Disk Access missing — scan limited to user directories")
            }

        case "keyloggerDetection":
            let accessibility = permissions.first { $0.type == .accessibility }
            if let acc = accessibility, acc.isGranted {
                return (true, nil)
            } else {
                return (false, "Accessibility permission missing — keylogger detection unavailable")
            }

        case "browserTabCounting":
            let appleEvents = permissions.first { $0.type == .appleEvents }
            if let ae = appleEvents, ae.isGranted {
                return (true, nil)
            } else if let ae = appleEvents, ae.status == .unknown {
                return (false, "Apple Events status unknown — verification pending")
            } else {
                return (false, "Apple Events permission missing — browser tab counting unavailable")
            }

        case "notifications":
            let notifications = permissions.first { $0.type == .notifications }
            if let notif = notifications, notif.isGranted {
                return (true, nil)
            } else {
                return (false, "Notifications disabled — alerts will not appear")
            }

        default:
            return (true, nil)
        }
    }
}
